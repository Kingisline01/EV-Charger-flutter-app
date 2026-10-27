#!/bin/bash
# ==============================================================================
# ChargeShare Mobile & Web Production Build Script
# Builds Android APK / App Bundle, iOS IPA, and Flutter Web for Ubuntu Hosting
# ==============================================================================
set -euo pipefail

ENV_FILE="${1:-deploy/.env.production}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Usage: ./deploy/build-mobile.sh <path-to-env-file>"
  echo "Defaulting to .env in root if present..."
  ENV_FILE=".env"
fi

echo "Loading environment variables from $ENV_FILE..."
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

SERVER_URL="${API_EXTERNAL_URL:-https://api.yourdomain.com}"
ANON_KEY="${ANON_KEY:-your-anon-key}"

echo "=========================================================="
echo "⚡ Building ChargeShare with Target Backend: $SERVER_URL"
echo "=========================================================="

# 1. Clean and fetch dependencies
flutter clean
flutter pub get

# 2. Build Android APK (Release with Proguard optimization)
echo "Building Android Release APK..."
flutter build apk --release \
  --dart-define=SUPABASE_URL="$SERVER_URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
  --dart-define=DEMO_MODE=false

# 3. Build Android App Bundle (Google Play Store AAB)
echo "Building Android Play Store App Bundle (AAB)..."
flutter build appbundle --release \
  --dart-define=SUPABASE_URL="$SERVER_URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
  --dart-define=DEMO_MODE=false

# 4. Build Flutter Web (Can be copied directly to /var/www/chargeshare/web on Ubuntu)
echo "Building Flutter Web for Ubuntu hosting..."
flutter build web --release \
  --dart-define=SUPABASE_URL="$SERVER_URL" \
  --dart-define=SUPABASE_ANON_KEY="$ANON_KEY" \
  --dart-define=DEMO_MODE=false

echo "=========================================================="
echo "Build Artifacts Generated:"
echo "• Android APK: build/app/outputs/flutter-apk/app-release.apk"
echo "• Android AAB: build/app/outputs/bundle/release/app-release.aab"
echo "• Web App:     build/web/ (Ready to copy to Ubuntu /var/www/chargeshare/web)"
echo "=========================================================="
