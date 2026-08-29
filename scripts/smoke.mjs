import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath, pathToFileURL } from "node:url"
import { WASI } from "node:wasi"

const root = dirname(dirname(fileURLToPath(import.meta.url)))
const dist = join(root, "dist")
const baseTar = readFileSync(join(dist, "sysroot-base.tar"))
const threadsTar = readFileSync(join(dist, "sysroot-threads.tar"))
const Clang = (await import(pathToFileURL(join(dist, "clang.js")))).default
const LLD = (await import(pathToFileURL(join(dist, "lld.js")))).default

function text(bytes) {
  return new TextDecoder().decode(bytes).replace(/\0.*$/s, "")
}

function* entries(data) {
  let offset = 0
  while (offset + 512 <= data.length) {
    const header = data.subarray(offset, offset + 512)
    const shortName = text(header.subarray(0, 100))
    if (!shortName) return
    const prefix = text(header.subarray(345, 500))
    const name = (prefix ? `${prefix}/${shortName}` : shortName).replace(/^\.\//, "")
    const size = Number.parseInt(text(header.subarray(124, 136)).trim(), 8) || 0
    const start = offset + 512
    yield { name, content: data.subarray(start, start + size) }
    offset = start + Math.ceil(size / 512) * 512
  }
}

function install(module, archives) {
  for (const archive of archives) {
    for (const { name, content } of entries(archive)) {
      if (!name || name.endsWith("/")) continue
      const parent = name.split("/").slice(0, -1).join("/")
      module.FS.mkdirTree(`/${parent}`)
      module.FS.writeFile(`/${name}`, content)
    }
  }
}

async function invocation(fileName, source, flags) {
  let stderr = ""
  const clang = await Clang({ thisProgram: "clang++", printErr: value => { stderr += `${value}\n` } })
  clang.FS.writeFile(fileName, source)
  for (const target of ["wasm32-wasip1", "wasm32-wasip1-threads"]) {
    clang.FS.mkdirTree(`/lib/${target}`)
    clang.FS.writeFile(`/lib/${target}/crt1-command.o`, new Uint8Array())
    clang.FS.writeFile(`/lib/${target}/crt1-reactor.o`, new Uint8Array())
  }
  clang.FS.mkdirTree("/include/c++/v1")
  const result = clang.callMain([fileName, ...flags, "-###"])
  if (result !== 0) throw new Error(stderr)
  const lines = stderr.split("\n")
  const parse = key => {
    const line = lines.find(value => value.includes(key)) || ""
    const args = [...line.matchAll(/"([^"]*)"/g)].map(value => value[1]).slice(1)
    const output = args[args.indexOf("-o") + 1]
    if (!output) throw new Error(`missing ${key} invocation\n${stderr}`)
    return { args, output }
  }
  return { compiler: parse("-cc1"), linker: parse("wasm-ld") }
}

async function compile(fileName, source, flags, archives) {
  let stderr = ""
  const [plan, clang, lld] = await Promise.all([
    invocation(fileName, source, flags),
    Clang({ thisProgram: "clang++", printErr: value => { stderr += `${value}\n` } }),
    LLD({ thisProgram: "wasm-ld", printErr: value => { stderr += `${value}\n` } })
  ])
  install(clang, archives)
  clang.FS.writeFile(fileName, source)
  if (clang.callMain(plan.compiler.args) !== 0) throw new Error(stderr)
  const object = clang.FS.readFile(plan.compiler.output, { encoding: "binary" })
  install(lld, archives)
  lld.FS.writeFile(plan.compiler.output, object)
  if (lld.callMain(plan.linker.args) !== 0) throw new Error(stderr)
  return WebAssembly.compile(lld.FS.readFile(plan.linker.output, { encoding: "binary" }))
}

const exceptionFlags = [
  "--target=wasm32-wasip1",
  "-std=c++23",
  "-fwasm-exceptions",
  "-mllvm",
  "-wasm-use-legacy-eh=false",
  "-lunwind"
]
const threadFlags = [
  "--target=wasm32-wasip1-threads",
  "-pthread",
  "-std=c++23",
  "-fwasm-exceptions",
  "-mllvm",
  "-wasm-use-legacy-eh=false",
  "-lunwind",
  "-Wl,--import-memory",
  "-Wl,--initial-memory=2097152",
  "-Wl,--max-memory=268435456"
]

const base = await compile("base.cpp", readFileSync(join(root, "tests", "base.cpp"), "utf8"), exceptionFlags, [baseTar])
const wasi = new WASI({ version: "preview1", args: [], env: {}, returnOnExit: true })
const instance = await WebAssembly.instantiate(base, { wasi_snapshot_preview1: wasi.wasiImport })
const exitCode = wasi.start(instance)
if (exitCode !== 0) throw new Error(`base smoke test exited ${exitCode}`)
await compile("threads.cpp", readFileSync(join(root, "tests", "threads.cpp"), "utf8"), threadFlags, [baseTar, threadsTar])
process.stdout.write("toolchain smoke tests passed\n")
