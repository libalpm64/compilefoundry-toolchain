set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build"
DIST="$ROOT/dist"
LLVM_COMMIT="278c31bfb8ceb7ea17dbfd11a4fb21e6634af957"
WASI_TAG="wasi-sdk-34-rc.2"
WASI_VERSION="34.0-rc.2+m"
SYSROOT_SHA256="d69cb4e2c355d63a4b7f2ed5c5333373ef7a919d776744d9b83ff3e0b98bdf89"
BUILTINS_SHA256="f102ed81f501e90722bca8fb609e4071f2e4cfd995ea68d86393ae1ca96fc5e8"

cmake -E make_directory "$BUILD" "$DIST"
cmake -E remove_directory "$DIST"
cmake -E make_directory "$DIST"

if [ ! -d "$BUILD/llvm-project/.git" ]; then
    git clone --filter=blob:none --no-checkout https://github.com/llvm/llvm-project.git "$BUILD/llvm-project"
fi

git -C "$BUILD/llvm-project" fetch --depth 1 origin "$LLVM_COMMIT"
git -C "$BUILD/llvm-project" checkout --detach "$LLVM_COMMIT"

emcmake cmake -S "$BUILD/llvm-project/llvm" -B "$BUILD/llvm" \
    -GNinja \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DCMAKE_C_FLAGS="-msimd128 -mbulk-memory" \
    -DCMAKE_CXX_FLAGS="-msimd128 -mbulk-memory" \
    -DCMAKE_EXE_LINKER_FLAGS="-s NO_INVOKE_RUN -s EXIT_RUNTIME -s STACK_SIZE=4194304 -s INITIAL_HEAP=134217728 -s ALLOW_MEMORY_GROWTH -s MODULARIZE -s EXPORT_ES6 -s MALLOC=dlmalloc -s EXPORTED_RUNTIME_METHODS=FS,callMain" \
    -DLLVM_ENABLE_PROJECTS="clang;lld" \
    -DLLVM_HOST_TRIPLE=wasm32-unknown-emscripten \
    -DLLVM_DEFAULT_TARGET_TRIPLE=wasm32-unknown-wasip1 \
    -DLLVM_TARGETS_TO_BUILD=WebAssembly \
    -DLLVM_ENABLE_THREADS=OFF \
    -DLLVM_BUILD_TOOLS=OFF \
    -DLLVM_INCLUDE_TESTS=OFF \
    -DCLANG_ENABLE_ARCMT=OFF \
    -DCLANG_ENABLE_STATIC_ANALYZER=OFF

ninja -C "$BUILD/llvm" lld clang

CLANG_JS="$(find "$BUILD/llvm/bin" -maxdepth 1 -type f -name 'clang.js-*' -print -quit)"
test -n "$CLANG_JS"
cp "$CLANG_JS" "$DIST/clang.js"
cp "$BUILD/llvm/bin/clang.wasm" "$DIST/clang.wasm"
cp "$BUILD/llvm/bin/lld.js" "$DIST/lld.js"
cp "$BUILD/llvm/bin/lld.wasm" "$DIST/lld.wasm"

curl -L --fail --retry 3 -o "$BUILD/wasi-sysroot.tar.gz" "https://github.com/WebAssembly/wasi-sdk/releases/download/$WASI_TAG/wasi-sysroot-$WASI_VERSION.tar.gz"
curl -L --fail --retry 3 -o "$BUILD/libclang-rt.tar.gz" "https://github.com/WebAssembly/wasi-sdk/releases/download/$WASI_TAG/libclang_rt-$WASI_VERSION.tar.gz"

echo "$SYSROOT_SHA256  $BUILD/wasi-sysroot.tar.gz" | sha256sum --check
echo "$BUILTINS_SHA256  $BUILD/libclang-rt.tar.gz" | sha256sum --check

cmake -E remove_directory "$BUILD/sysroot"
cmake -E remove_directory "$BUILD/builtins"
cmake -E make_directory "$BUILD/sysroot" "$BUILD/builtins"
tar -xzf "$BUILD/wasi-sysroot.tar.gz" -C "$BUILD/sysroot" --strip-components 1
tar -xzf "$BUILD/libclang-rt.tar.gz" -C "$BUILD/builtins" --strip-components 1

cmake -E remove_directory "$BUILD/sysroot/include/wasm32-wasip2"
cmake -E remove_directory "$BUILD/sysroot/include/wasm32-wasip3"
cmake -E remove_directory "$BUILD/sysroot/lib/wasm32-wasip2"
cmake -E remove_directory "$BUILD/sysroot/lib/wasm32-wasip3"
find "$BUILD/sysroot/lib" -type d -name llvm-lto -prune -exec rm -rf '{}' '+'
find "$BUILD/sysroot/lib" -type f -name '*.so' -delete

cmake -E make_directory "$BUILD/sysroot/lib/clang/23/include"
cmake -E copy_directory "$BUILD/llvm/lib/clang/23/include" "$BUILD/sysroot/lib/clang/23/include"

for TARGET in wasm32-unknown-wasip1 wasm32-unknown-wasip1-threads; do
    cmake -E make_directory "$BUILD/sysroot/lib/clang/23/lib/$TARGET"
    cp "$BUILD/builtins/$TARGET/libclang_rt.builtins.a" "$BUILD/sysroot/lib/clang/23/lib/$TARGET/libclang_rt.builtins.a"
done

cmake -E make_directory "$BUILD/sysroot/include/c++/v1/bits"
cp "$ROOT/compat/include/generator" "$BUILD/sysroot/include/c++/v1/generator"
cp "$ROOT/compat/include/bits/stdc++.h" "$BUILD/sysroot/include/c++/v1/bits/stdc++.h"

(cd "$BUILD/sysroot" && tar --format=ustar -cf "$DIST/sysroot.tar" *)

cd "$DIST"
sha256sum clang.js clang.wasm lld.js lld.wasm sysroot.tar > SHA256SUMS
node "$ROOT/scripts/manifest.mjs" > manifest.json

