import { readFileSync, statSync } from "node:fs"

const hashes = Object.fromEntries(
  readFileSync("SHA256SUMS", "utf8")
    .trim()
    .split("\n")
    .map(line => {
      const [sha256, name] = line.trim().split(/\s+/)
      return [name, sha256]
    })
)

const files = Object.fromEntries(
  Object.entries(hashes).map(([name, sha256]) => [
    name,
    { sha256, bytes: statSync(name).size }
  ])
)

process.stdout.write(JSON.stringify({
  schemaVersion: 1,
  llvmCommit: "278c31bfb8ceb7ea17dbfd11a4fb21e6634af957",
  wasiSdk: "34.0-rc.2+m",
  emsdk: "6.0.8",
  targets: ["wasm32-wasip1", "wasm32-wasip1-threads"],
  files
}, null, 2) + "\n")

