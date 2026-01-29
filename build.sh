#!/usr/bin/env bash
set -euo pipefail

echo "[+] Starting Morphe build"

# -------------------------------------------------
# Load app versions
# -------------------------------------------------
source versions.env

echo "YouTube version: $YOUTUBE_VERSION"
echo "Music version: $MUSIC_VERSION"
echo "Reddit version: $REDDIT_VERSION"

# -------------------------------------------------
# Load Morphe versions
# -------------------------------------------------
PATCH_VERSION="${PATCH_VERSION:?PATCH_VERSION not set}"
CLI_VERSION="${CLI_VERSION:?CLI_VERSION not set}"
APKEDITOR_URL="${APKEDITOR_URL:?APKEDITOR_URL not set}"

echo "Morphe patch version: $PATCH_VERSION"
echo "Morphe CLI version: $CLI_VERSION"

# -------------------------------------------------
# APK URLs
# -------------------------------------------------
YOUTUBE_APK_URL="https://archive.org/download/you-tube-20.40.45/YouTube%2020.40.45.apk"
MUSIC_APK_URL="https://archive.org/download/you-tube-20.40.45/Music%208.40.54.apk"
REDDIT_APKM_URL="https://archive.org/download/you-tube-20.40.45-bundle/Reddit%202026.04.0%20BUNDLE.apkm"

# -------------------------------------------------
# Tool URLs
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
# Download APKs (YouTube & Music) — HARD REQUIRED
# -------------------------------------------------
download_apk "$YOUTUBE_APK_URL" temp/youtube.apk
download_apk "$MUSIC_APK_URL" temp/music.apk

# -------------------------------------------------
# Download tools (required)
# -------------------------------------------------
curl -L --fail "$CLI_URL" -o tools/morphe-cli.jar
curl -L --fail "$PATCHES_URL" -o patches/patches.mpp
curl -L --fail "$APKEDITOR_URL" -o tools/apkeditor.jar

# -------------------------------------------------
# OPTIONAL: Reddit flow (must NOT stop CI)
# -------------------------------------------------
set +e
echo "[+] Processing Reddit (optional)"

curl -L --fail --retry 3 "$REDDIT_APKM_URL" -o temp/reddit.apkm
REDDIT_OK=$?

if [ $REDDIT_OK -eq 0 ]; then
  java -jar tools/apkeditor.jar m \
    -f \
    -i temp/reddit.apkm \
    -o temp/reddit.apk

  if [ $? -eq 0 ]; then
    java -jar tools/morphe-cli.jar patch \
      --keystore morphe-release.bks \
      --keystore-password "$KEYSTORE_PASSWORD" \
      --keystore-entry-alias "$KEY_ALIAS" \
      --keystore-entry-password "$KEY_PASSWORD" \
      -p patches/patches.mpp \
      -o build/Reddit-Morphe.apk \
      --purge \
      temp/reddit.apk
  else
    echo "Reddit merge failed, skipping patch"
  fi
else
  echo "Reddit download failed, skipping Reddit build"
fi
set -e

# -------------------------------------------------
# Patch YouTube (MUST SUCCEED)
# -------------------------------------------------
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
# Patch Music (MUST SUCCEED)
# -------------------------------------------------
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
