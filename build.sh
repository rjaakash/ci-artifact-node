#!/usr/bin/env bash
set -euo pipefail

echo "[+] Starting Morphe build"

# =================================================
# Versions & URLs resolved by workflow
# =================================================
YOUTUBE_VERSION="${YOUTUBE_VERSION:?missing}"
MUSIC_VERSION="${MUSIC_VERSION:?missing}"
REDDIT_VERSION="${REDDIT_VERSION:?missing}"

YOUTUBE_APK_URL="${YOUTUBE_APK_URL:?missing}"
MUSIC_APK_URL="${MUSIC_APK_URL:?missing}"
REDDIT_APKM_URL="${REDDIT_APKM_URL:?missing}"

PATCH_VERSION="${PATCH_VERSION:?missing}"
CLI_VERSION="${CLI_VERSION:?missing}"
APKEDITOR_URL="${APKEDITOR_URL:?missing}"

CLI_URL="https://github.com/MorpheApp/morphe-cli/releases/download/v${CLI_VERSION}/morphe-cli-${CLI_VERSION}-all.jar"
PATCHES_URL="https://github.com/MorpheApp/morphe-patches/releases/download/v${PATCH_VERSION}/patches-${PATCH_VERSION}.mpp"

rm -rf temp tools patches build
mkdir -p temp tools patches build

download_apk () {
  curl -L --fail --retry 3 "$1" -o "$2"
  file "$2" | grep -qi "Android package"
}

download_apk "$YOUTUBE_APK_URL" temp/youtube.apk
download_apk "$MUSIC_APK_URL" temp/music.apk

curl -L --fail "$CLI_URL" -o tools/morphe-cli.jar
curl -L --fail "$PATCHES_URL" -o patches/patches.mpp
curl -L --fail "$APKEDITOR_URL" -o tools/apkeditor.jar

set +e
curl -L --fail "$REDDIT_APKM_URL" -o temp/reddit.apkm
if [ $? -eq 0 ]; then
  java -jar tools/apkeditor.jar m -f -i temp/reddit.apkm -o temp/reddit.apk
  java -jar tools/morphe-cli.jar patch \
    --keystore morphe-release.bks \
    --keystore-password "$KEYSTORE_PASSWORD" \
    --keystore-entry-alias "$KEY_ALIAS" \
    --keystore-entry-password "$KEY_PASSWORD" \
    -p patches/patches.mpp \
    -o build/Reddit-Morphe.apk \
    --purge temp/reddit.apk
fi
set -e

java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -o build/YouTube-Morphe.apk \
  --purge temp/youtube.apk

java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -o build/Music-Morphe.apk \
  --purge temp/music.apk

echo "[✓] Build completed successfully"
