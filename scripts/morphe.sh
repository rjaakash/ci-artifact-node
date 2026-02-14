#!/usr/bin/env bash
# Fail fast:
# -e  : exit on error
# -u  : error on unset variables
# -o pipefail : catch errors in pipelines
set -euo pipefail

echo "[+] Starting Morphe build"

# =================================================
# Load app versions (workflow-controlled)
# -------------------------------------------------
# These variables are resolved in the workflow
# from the ci-artifact-index repository.
# =================================================
YOUTUBE_VERSION="${YOUTUBE_VERSION:?YOUTUBE_VERSION not set}"
MUSIC_VERSION="${MUSIC_VERSION:?MUSIC_VERSION not set}"
REDDIT_VERSION="${REDDIT_VERSION:-}"

echo "YouTube version: $YOUTUBE_VERSION"
echo "Music version: $MUSIC_VERSION"
echo "Reddit version: $REDDIT_VERSION"

# =================================================
# Load Morphe versions (workflow-controlled)
# -------------------------------------------------
# These variables are injected by GitHub Actions:
#   - PATCH_VERSION   (latest stable Morphe patch)
#   - CLI_VERSION     (latest stable Morphe CLI)
#   - APKEDITOR_URL   (latest stable APKEditor jar)
# Script will abort immediately if any are missing.
# =================================================
PATCH_VERSION="${PATCH_VERSION:?PATCH_VERSION not set}"
CLI_VERSION="${CLI_VERSION:?CLI_VERSION not set}"
APKEDITOR_URL="${APKEDITOR_URL:-}"

echo "Morphe patch version: $PATCH_VERSION"
echo "Morphe CLI version: $CLI_VERSION"

# =================================================
# Source APK locations (workflow-controlled)
# -------------------------------------------------
# These URLs are resolved from ci-artifact-index
# and injected by the workflow.
# =================================================
YOUTUBE_APK_URL="${YOUTUBE_APK_URL:?YOUTUBE_APK_URL not set}"
MUSIC_APK_URL="${MUSIC_APK_URL:?MUSIC_APK_URL not set}"
REDDIT_APKM_URL="${REDDIT_APKM_URL:-}"

# =================================================
# Morphe tooling download URLs
# -------------------------------------------------
CLI_URL="https://github.com/MorpheApp/morphe-cli/releases/download/v${CLI_VERSION}/morphe-cli-${CLI_VERSION}-all.jar"
PATCHES_URL="https://github.com/MorpheApp/morphe-patches/releases/download/v${PATCH_VERSION}/patches-${PATCH_VERSION}.mpp"

# =================================================
# Prepare clean workspace
# -------------------------------------------------
# Always start fresh to avoid CI leftovers.
# =================================================
rm -rf temp tools patches build
mkdir -p temp tools patches build

# =================================================
# Helper: download and validate APK
# -------------------------------------------------
# Ensures the downloaded file is a real Android APK.
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
# Download REQUIRED base APKs
# -------------------------------------------------
# These MUST succeed or the build should fail.
# =================================================
download_apk "$YOUTUBE_APK_URL" temp/youtube.apk
download_apk "$MUSIC_APK_URL" temp/music.apk

# =================================================
# Download REQUIRED build tools
# -------------------------------------------------
# Morphe CLI and patches are mandatory.
# APKEditor is optional (used only for Reddit).
# =================================================
curl -L --fail "$CLI_URL" -o tools/morphe-cli.jar
curl -L --fail "$PATCHES_URL" -o patches/patches.mpp

if [ -n "$APKEDITOR_URL" ]; then
  set +e
  curl -L --fail "$APKEDITOR_URL" -o tools/apkeditor.jar
  APKEDITOR_OK=$?
  set -e
else
  APKEDITOR_OK=1
fi

# =================================================
# OPTIONAL: Reddit build pipeline
# -------------------------------------------------
# Reddit is bundled as APKM and may fail.
# Failure here MUST NOT stop YouTube/Music builds.
# =================================================
if [ -n "$REDDIT_APKM_URL" ] && [ "$APKEDITOR_OK" -eq 0 ]; then
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
fi

# =================================================
# Patch YouTube (CRITICAL)
# -------------------------------------------------
# Must always succeed. Build fails if this fails.
# =================================================
java -jar tools/morphe-cli.jar patch \
  --keystore morphe-release.bks \
  --keystore-password "$KEYSTORE_PASSWORD" \
  --keystore-entry-alias "$KEY_ALIAS" \
  --keystore-entry-password "$KEY_PASSWORD" \
  -p patches/patches.mpp \
  -o build/YouTube-Morphe.apk \
  --purge \
  temp/youtube.apk

# =================================================
# Patch Music (CRITICAL)
# -------------------------------------------------
# Must always succeed. Build fails if this fails.
# =================================================
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
