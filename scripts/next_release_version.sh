#!/bin/sh
set -eu

CURRENT_VERSION="${1:-0.1.0}"

case "$CURRENT_VERSION" in
    *[!0-9.]* | *.*.*.* | .* | *. | *..*)
        echo "Invalid version: $CURRENT_VERSION" >&2
        exit 1
        ;;
esac

OLD_IFS="$IFS"
IFS=.
set -- $CURRENT_VERSION
IFS="$OLD_IFS"

if [ "$#" -ne 3 ]; then
    echo "Invalid version: $CURRENT_VERSION" >&2
    exit 1
fi

MAJOR="$1"
MINOR="$2"
PATCH="$3"

if [ "$PATCH" -ge 99 ]; then
    MINOR=$((MINOR + 1))
    PATCH=0
else
    PATCH=$((PATCH + 1))
fi

echo "$MAJOR.$MINOR.$PATCH"
