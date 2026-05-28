#!/bin/bash
set -euo pipefail

APP_NAME="ztp"
BUNDLE_ID="dev.zyquo.ztp"
VERSION="0.3.0"
IDENTITY="Developer ID Application: Simon-Pierre Boucher (3YM54G49SN)"
KEYCHAIN_PROFILE="MacLustr-Notarize"
ENTITLEMENTS="Entitlements/ZTP.entitlements"
ZIP_NAME="ZTP.zip"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

release() {
    echo "==> Building release..."
    swift build -c release
    echo "    Release build complete."
    echo "    Binary: .build/release/${APP_NAME}"
    ls -lh ".build/release/${APP_NAME}"
}

sign() {
    echo "==> Signing with Developer ID..."

    local BINARY=".build/release/${APP_NAME}"
    if [ ! -f "${BINARY}" ]; then
        echo "    Error: Binary not found. Run '$0 release' first."
        exit 1
    fi

    codesign --force --options runtime \
        --entitlements "${ENTITLEMENTS}" \
        --sign "${IDENTITY}" \
        --timestamp \
        "${BINARY}"

    echo "    Signed: ${BINARY}"
}

zip_pkg() {
    echo "==> Creating ZIP for notarization..."

    local BINARY=".build/release/${APP_NAME}"
    if [ ! -f "${BINARY}" ]; then
        echo "    Error: Binary not found. Run '$0 release' first."
        exit 1
    fi

    rm -f "${ZIP_NAME}"
    ditto -c -k --keepParent "${BINARY}" "${ZIP_NAME}"
    echo "    ZIP created: ${ZIP_NAME}"
}

notarize() {
    echo "==> Submitting for notarization..."

    if [ ! -f "${ZIP_NAME}" ]; then
        echo "    Error: ZIP not found. Run '$0 zip' first."
        exit 1
    fi

    xcrun notarytool submit "${ZIP_NAME}" \
        --keychain-profile "${KEYCHAIN_PROFILE}" \
        --wait

    echo "    Notarization complete."
}

tarball() {
    echo "==> Creating Homebrew tarball..."

    local BINARY=".build/release/${APP_NAME}"
    if [ ! -f "${BINARY}" ]; then
        echo "    Error: Binary not found."
        exit 1
    fi

    local TARBALL="${APP_NAME}-${VERSION}-macos-arm64.tar.gz"
    local STAGING_DIR=$(mktemp -d)
    cp "${BINARY}" "${STAGING_DIR}/"
    tar -czf "${TARBALL}" -C "${STAGING_DIR}" "${APP_NAME}"
    rm -rf "${STAGING_DIR}"

    local SHA=$(shasum -a 256 "${TARBALL}" | awk '{print $1}')
    echo "    Tarball: ${TARBALL}"
    echo "    SHA256:  ${SHA}"
    echo ""
    echo "    Use this SHA256 in the Homebrew formula."
}

verify() {
    echo "==> Verifying signatures..."

    local BINARY=".build/release/${APP_NAME}"
    if [ ! -f "${BINARY}" ]; then
        echo "    Error: Binary not found."
        exit 1
    fi

    echo "--- codesign ---"
    codesign -dvv "${BINARY}" 2>&1 || true

    echo ""
    echo "--- spctl (Gatekeeper) ---"
    spctl -a -t execute -vv "${BINARY}" 2>&1 || true

    echo ""
    echo "    Verification complete."
}

dist() {
    echo "========================================="
    echo "  ZTP — Full Distribution Build"
    echo "========================================="
    release
    sign
    zip_pkg
    notarize
    tarball
    verify
    echo ""
    echo "  Distribution complete!"
    echo "  Binary: .build/release/${APP_NAME}"
    echo "  Tarball: ${APP_NAME}-${VERSION}-macos-arm64.tar.gz"
    echo "========================================="
}

clean() {
    echo "==> Cleaning..."
    rm -f "${ZIP_NAME}" ${APP_NAME}-*-macos-arm64.tar.gz
    echo "    Clean complete."
}

help() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  release    Release build (swift build -c release)"
    echo "  sign       Code sign with Developer ID"
    echo "  zip        Create ZIP for notarization submission"
    echo "  notarize   Submit to Apple notarization"
    echo "  tarball    Create Homebrew distribution tarball"
    echo "  verify     Verify code signatures"
    echo "  dist       Full pipeline: release → sign → zip → notarize → tarball → verify"
    echo "  clean      Remove distribution artifacts"
    echo ""
}

case "${1:-help}" in
    release)   release ;;
    sign)      sign ;;
    zip)       zip_pkg ;;
    notarize)  notarize ;;
    tarball)   tarball ;;
    verify)    verify ;;
    dist)      dist ;;
    clean)     clean ;;
    *)         help ;;
esac
