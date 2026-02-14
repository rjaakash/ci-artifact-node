#!/usr/bin/env bash
# Fail fast:
# -e  : exit on error
# -u  : error on unset variables
# -o pipefail : catch errors in pipelines
set -euo pipefail

echo "[+] Starting Anddea build"

# =================================================
# Load app versions (workflow-controlled)
# =================================================
YOUTUBE_VERSION="${YOUTUBE_VERSION:?YOUTUBE_VERSION not set}"
MUSIC_VERSION="${MUSIC_VERSION:?MUSIC_VERSION not set}"

echo "YouTube version: $YOUTUBE_VERSION"
echo "Music version: $MUSIC_VERSION"

# =================================================
# Load Anddea patch + Morphe CLI versions
# =================================================
PATCH_VERSION="${PATCH_VERSION:?PATCH_VERSION not set}"
CLI_VERSION="${CLI_VERSION:?CLI_VERSION not set}"

echo "Anddea patch version: $PATCH_VERSION"
echo "Morphe CLI version: $CLI_VERSION"

# =================================================
# Source APK locations (workflow-controlled)
# =================================================
YOUTUBE_APK_URL="${YOUTUBE_APK_URL:?YOUTUBE_APK_URL not set}"
MUSIC_APK_URL="${MUSIC_APK_URL:?MUSIC_APK_URL not set}"

# =================================================
# Tool download URLs
# =================================================
CLI_URL="https://github.com/MorpheApp/morphe-cli/releases/download/v${CLI_VERSION}/morphe-cli-${CLI_VERSION}-all.jar"
PATCHES_URL="https://github.com/anddea/revanced-patches/releases/download/v${PATCH_VERSION}/patches-${PATCH_VERSION}.mpp"

# =================================================
# Prepare clean workspace
# =================================================
rm -rf temp tools patches build
mkdir -p temp tools patches build

# =================================================
# Helper: download and validate APK
# =================================================
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

# =================================================
# Download required base APKs
# =================================================
download_apk "$YOUTUBE_APK_URL" temp/youtube.apk
download_apk "$MUSIC_APK_URL" temp/music.apk

# =================================================
# Download Morphe CLI + Anddea patches
# =================================================
curl -L --fail "$CLI_URL" -o tools/morphe-cli.jar
curl -L --fail "$PATCHES_URL" -o patches/patches.mpp

# =================================================
# Patch YouTube (CRITICAL)
# =================================================
java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -e 'Custom branding name for YouTube' \
  -e 'Custom header for YouTube' \
  -e 'Hide shortcuts' \
  -e 'Theme' \
  -e 'Custom branding icon for YouTube' \
  -OappIcon=xisr_yellow \
  -OrestoreOldSplashAnimation=true \
  -e 'Overlay buttons' \
  -OiconType=rounded \
  -e 'Settings for YouTube' \
  -OrvxSettingsLabel=Anddea \
  -e 'Visual preferences icons for YouTube' \
  -OsettingsMenuIcon=rvx_letters_bold \
  -OapplyToAll=false \
  -o build/YouTube-Anddea.apk \
  --purge \
  temp/youtube.apk

# =================================================
# Patch Music (CRITICAL)
# =================================================
java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -e 'Custom header for YouTube Music' \
  -e 'Custom branding icon for YouTube Music' \
  -OappIcon=xisr_yellow \
  -OrestoreOldSplashIcon=true \
  -e 'Custom branding name for YouTube Music' \
  -OappNameNotification=Music \
  -OappNameLauncher=Music \
  -e 'Settings for YouTube Music' \
  -OrvxSettingsLabel=Anddea \
  -e 'Visual preferences icons for YouTube Music' \
  -OsettingsMenuIcon=rvx_letters_bold \
  -OapplyToAll=false \
  -o build/Music-Anddea.apk \
  --purge \
  temp/music.apk

echo "[✓] Anddea build completed successfully"
