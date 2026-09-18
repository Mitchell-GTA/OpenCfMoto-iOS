#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "========================================="
echo "🏍️  Compilando OpenCfMoto para iOS (.ipa)"
echo "========================================="

echo "==> Limpiando compilaciones anteriores..."
rm -rf build OpenCfMoto.ipa Payload

echo "==> Compilando aplicación en modo Release..."
xcodebuild build \
  -project OpenCfMoto.xcodeproj \
  -scheme OpenCfMoto \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

APP_PATH=$(find ./build/Build/Products -name "OpenCfMoto.app" -type d | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "❌ Error: No se encontró el bundle OpenCfMoto.app en ./build"
  exit 1
fi

echo "==> Bundle encontrado en: $APP_PATH"
echo "==> Empaquetando Payload en OpenCfMoto.ipa..."
mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r -q -y OpenCfMoto.ipa Payload
rm -rf Payload

echo ""
echo "========================================="
echo "✅ IPA Generado con éxito:"
echo "   $PROJECT_DIR/OpenCfMoto.ipa"
echo "========================================="
ls -lh OpenCfMoto.ipa
