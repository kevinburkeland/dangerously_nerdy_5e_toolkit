#!/usr/bin/env bash
set -e

# Resolve repository root directory regardless of current working directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

cd "$ROOT_DIR"

echo "Building Flutter Web application from $ROOT_DIR..."
flutter build web --no-tree-shake-icons

BUILD_TIMESTAMP=$(date +%s)
echo "Injecting dynamic build version ($BUILD_TIMESTAMP) into service workers, bootstrap loader, and html..."

# 1. Substitute placeholder in sw.js and mirror to flutter_service_worker.js
sed "s/BUILD_TIMESTAMP_PLACEHOLDER/$BUILD_TIMESTAMP/g" "$ROOT_DIR/web/sw.js" > "$ROOT_DIR/build/web/sw.js"
cp "$ROOT_DIR/build/web/sw.js" "$ROOT_DIR/build/web/flutter_service_worker.js"

# 2. Inject version into build/web/index.html
sed -i "s/BUILD_TIMESTAMP_PLACEHOLDER/$BUILD_TIMESTAMP/g" "$ROOT_DIR/build/web/index.html"

# 3. Inject dynamic version into flutter_bootstrap.js so flutter loader always registers sw with latest timestamp and forces main.dart.js refresh
if [ -f "$ROOT_DIR/build/web/flutter_bootstrap.js" ]; then
  sed -i "s/serviceWorkerVersion: *\"[^\"]*\"/serviceWorkerVersion: \"$BUILD_TIMESTAMP\"/g" "$ROOT_DIR/build/web/flutter_bootstrap.js"
  sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=$BUILD_TIMESTAMP\"/g" "$ROOT_DIR/build/web/flutter_bootstrap.js"
fi

echo "Build complete! Web bundle in build/web is PWA install ready with version $BUILD_TIMESTAMP."
