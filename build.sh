#!/bin/bash
set -e

echo "=== Installing Flutter SDK ==="
if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
fi

export PATH="$PATH:$(pwd)/_flutter/bin"

echo "=== Configuring Flutter for Web ==="
flutter config --no-analytics
flutter config --enable-web

echo "=== Getting Dependencies ==="
flutter pub get

echo "=== Building Flutter Web Application ==="
flutter build web --release --no-tree-shake-icons

echo "=== Build Complete ==="
