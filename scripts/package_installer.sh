#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
BUNDLE_IDENTIFIER="local.codex.macmultiopen.app"
PACKAGE_IDENTIFIER="local.codex.macmultiopen.installer"
APP_SOURCE="$ROOT_DIR/dist/MacMultiOpen.app"
APP_INSTALL_NAME="微信多开工具.app"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_ROOT="$DIST_DIR/pkg-root"
PACKAGE_PATH="$DIST_DIR/微信多开工具-$VERSION-universal.pkg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"

cd "$ROOT_DIR"
VERSION="$VERSION" sh scripts/build_app.sh >/dev/null

rm -rf "$PACKAGE_ROOT"
rm -f "$PACKAGE_PATH"
mkdir -p "$PACKAGE_ROOT/Applications"
/usr/bin/ditto --norsrc --noextattr --noqtn "$APP_SOURCE" "$PACKAGE_ROOT/Applications/$APP_INSTALL_NAME"
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$PACKAGE_ROOT"
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    COPYFILE_DISABLE=1 pkgbuild \
        --root "$PACKAGE_ROOT" \
        --identifier "$PACKAGE_IDENTIFIER" \
        --version "$VERSION" \
        --install-location "/" \
        --filter '\.DS_Store$' \
        --filter '/\.svn($|/)' \
        --filter '/CVS($|/)' \
        --filter '(^|/)\._[^/]*$' \
        --sign "$SIGNING_IDENTITY" \
        "$PACKAGE_PATH" >/dev/null
else
    COPYFILE_DISABLE=1 pkgbuild \
        --root "$PACKAGE_ROOT" \
        --identifier "$PACKAGE_IDENTIFIER" \
        --version "$VERSION" \
        --install-location "/" \
        --filter '\.DS_Store$' \
        --filter '/\.svn($|/)' \
        --filter '/CVS($|/)' \
        --filter '(^|/)\._[^/]*$' \
        "$PACKAGE_PATH" >/dev/null
fi

rm -rf "$PACKAGE_ROOT"

pkgutil --payload-files "$PACKAGE_PATH" | grep -q "Applications/$APP_INSTALL_NAME/Contents/MacOS/MacMultiOpen$"

echo "$PACKAGE_PATH"
echo "identifier: $PACKAGE_IDENTIFIER"
echo "app-bundle: $BUNDLE_IDENTIFIER"
if [ -n "$SIGNING_IDENTITY" ]; then
    echo "signature: $SIGNING_IDENTITY"
else
    echo "signature: unsigned"
fi
