# compilefoundry-toolchain

Unified browser-hosted toolchain for CompileFoundry. User programs are compiled and executed in the browser; this repository never provides a server-side compile service.

## Outputs

- `clang.js`
- `clang.wasm.gz`
- `lld.js`
- `lld.wasm.gz`
- `sysroot-base.tar.gz`
- `sysroot-threads.tar.gz`
- `yaegi.wasm` / `yaegi.wasm.gz` — Yaegi 0.16.2 WASI built with Go 1.27 (`GOOS=wasip1`, symlink `go.wasm → yaegi.wasm` for unified `web/toolchain`); Yaegi provides Go 1.22-era language compatibility
- `rust-sysroot-wasip2.tar.gz` / `rust-wasi-test.wasm` — Rust stable WASI sysroot and smoke-test program; these are not a browser Rust compiler and are not exposed as runnable
- `typescript.js` / `typescript.js.gz` — official TypeScript 6.0.2 compiler API used by the `@typescript/typescript6` compatibility package (TypeScript 7.0.2 does not expose a programmatic API)
- `languages.json` — machine-readable browser execution boundary, versions, support levels, and limits
- `manifest.json`
- `SHA256SUMS`

## Versions

- LLVM commit `278c31bfb8ceb7ea17dbfd11a4fb21e6634af957`
- WASI SDK `34.0-rc.2+m`
- Emscripten SDK `6.0.8`
- Go host `1.27` with Yaegi `v0.16.2` on `wasip1` (Go 1.22-era interpreted syntax)
- Rust `stable` (`1.98.0` when last verified) for non-runnable WASI artifacts
- JavaScript `ECMAScript 2026` (the user's browser engine)
- TypeScript `6.0.2` compatibility compiler API; upstream TypeScript is `7.0.2`

## Build

Run the Build and Release workflow manually and enter the desired release tag. After all builds succeed, the workflow creates the tag if needed and publishes or updates the matching GitHub release. Pushes do not start builds.

The release job is idempotent: it creates a missing tag and release, or uploads the rebuilt assets to the existing release with `--clobber`. The VPS only serves these static files. Browser workers enforce the runtime limits declared in `languages.json`.
