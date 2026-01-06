#!/usr/bin/env bash
set -euo pipefail

echo "[+] Starting Morphe build"

# -------------------------------------------------
# Load app versions (YOU control these)
# -------------------------------------------------
source versions.env

echo "YouTube version: $YOUTUBE_VERSION"
echo "Music version: $MUSIC_VERSION"

# -------------------------------------------------
# Load Morphe versions (AUTO)
# -------------------------------------------------
PATCH_VERSION="$(cat morphe-patches-version.txt)"
CLI_VERSION="$(cat morphe-cli-version.txt)"

echo "Morphe patch version: $PATCH_VERSION"
echo "Morphe CLI version: $CLI_VERSION"

# -------------------------------------------------
# APK URLs (YOU update when needed)
# -------------------------------------------------
YOUTUBE_APK_URL="https://archive.org/download/com.google.android.youtube_20.37.48-1556891072_minapi28arm64-v8aarmeabi-v7ax86x8/com.google.android.youtube_20.37.48-1556891072_minAPI28%28arm64-v8a%2Carmeabi-v7a%2Cx86%2Cx86_64%29%28nodpi%29_apkmirror.com.apk"

MUSIC_APK_URL="https://archive.org/download/com.google.android.youtube_20.37.48-1556891072_minapi28arm64-v8aarmeabi-v7ax86x8/com.google.android.apps.youtube.music_8.37.56-83756240_minAPI26%28arm64-v8a%29%28nodpi%29_apkmirror.com.apk"

# -------------------------------------------------
# Morphe download URLs
# -------------------------------------------------
CLI_URL="https://github.com/MorpheApp/morphe-cli/releases/download/v${CLI_VERSION}/morphe-cli-${CLI_VERSION}-all.jar"
PATCHES_URL="https://github.com/MorpheApp/morphe-patches/releases/download/v${PATCH_VERSION}/patches-${PATCH_VERSION}.mpp"

# -------------------------------------------------
# Prepare folders
# -------------------------------------------------
rm -rf temp tools patches build
mkdir -p temp tools patches build

# -------------------------------------------------
# Helper: download + verify APK
# -------------------------------------------------
download_apk() {
  local url="$1"
  local out="$2"

  echo "[+] Downloading $out"
  curl -L --fail --retry 3 "$url" -o "$out"

  file "$out" | grep -qi "Android package" || {
    echo "ERROR: $out is not a valid APK"
    exit 1
  }
}

# -------------------------------------------------
# Download APKs
# -------------------------------------------------
download_apk "$YOUTUBE_APK_URL" temp/youtube.apk
download_apk "$MUSIC_APK_URL" temp/music.apk

# -------------------------------------------------
# Download Morphe CLI & patches
# -------------------------------------------------
echo "[+] Downloading Morphe CLI"
curl -L --fail "$CLI_URL" -o tools/morphe-cli.jar

echo "[+] Downloading Morphe patches"
curl -L --fail "$PATCHES_URL" -o patches/patches.mpp

# -------------------------------------------------
# Patch YouTube
# -------------------------------------------------
echo "[+] Patching YouTube"
java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -o build/YouTube-Morphe.apk \
  --purge \
  temp/youtube.apk

# -------------------------------------------------
# Patch Music
# -------------------------------------------------
echo "[+] Patching Music"
java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -o build/Music-Morphe.apk \
  --purge \
  temp/music.apk

echo "[✓] Build completed successfully"
