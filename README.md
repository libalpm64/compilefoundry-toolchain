# compilefoundry-toolchain

Unified browser-hosted toolchain for CompileFoundry — Clang, LLD, WASI sysroots, Go Yaegi, Rust WASI.

## Outputs

- `clang.js`
- `clang.wasm.gz`
- `lld.js`
- `lld.wasm.gz`
- `sysroot-base.tar.gz`
- `sysroot-threads.tar.gz`
- `yaegi.wasm` / `yaegi.wasm.gz` — Go 1.26 Yaegi WASI (`GOOS=wasip1`, `traefik/yaegi`, symlink `go.wasm → yaegi.wasm` for unified `web/toolchain`)
- `rust-sysroot-wasip2.tar.gz` / `rust-wasi-test.wasm` — Rust 1.88 `wasm32-wasip1/wasip2` (WASI 0.3, `wasm32-unknown-unknown` for `wasm-bindgen`)
- `manifest.json`
- `SHA256SUMS`

## Versions

- LLVM commit `278c31bfb8ceb7ea17dbfd11a4fb21e6634af957`
- WASI SDK `34.0-rc.2+m`
- Emscripten SDK `6.0.8`
- Go `1.26` (`Yaegi` `v0.16.2` `wasip1`)
- Rust `1.88` (`wasm32-wasip1`, `wasm32-wasip2` WASI 0.3, `wasm32-unknown-unknown`)

## Build

Run the Build and Release workflow manually with an existing release tag. Pushes do not start builds.
