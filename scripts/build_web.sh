#!/usr/bin/env bash
set -e

# Resolve repository root directory regardless of current working directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

cd "$ROOT_DIR"

echo "Building Flutter Web application from $ROOT_DIR..."
flutter build web

echo "Patching build/web/flutter_service_worker.js with active PWA Service Worker..."
cp "$ROOT_DIR/web/sw.js" "$ROOT_DIR/build/web/flutter_service_worker.js"

echo "Build complete! Web bundle in build/web is PWA install ready."
