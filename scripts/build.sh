#!/bin/bash
# neoos-os-builder's actual orchestration logic. Clones each dependency
# fresh into a scratch directory, builds them in order, then asks
# neoos-kernel to do the ISO/disk-image assembly itself (it already
# knows how -- this script doesn't reimplement that).
set -euo pipefail

CONFIG="${1:?usage: build.sh <config.yaml>}"
[ -f "$CONFIG" ] || { echo "error: config file not found: $CONFIG" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Minimal YAML reading without a parser dependency -- the config
# format is deliberately flat enough for this (see config/example.yaml).
# Every extraction strips a trailing `# comment` and surrounding
# whitespace/quotes FIRST, then takes the value -- config/example.yaml
# ships with an inline comment on `tests.include` specifically to make
# sure this doesn't regress silently.
strip_comment() { sed 's/#.*//'; }
trim() { sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//'; }

KERNEL_REF=$(grep -A2 '^kernel:' "$CONFIG" | grep 'version:' | strip_comment | sed 's/.*://' | trim)
KERNEL_REF="${KERNEL_REF:-main}"
TESTS_INCLUDE=$(grep -A2 '^tests:' "$CONFIG" 2>/dev/null | grep 'include:' | strip_comment | sed 's/.*://' | trim)
TESTS_INCLUDE="${TESTS_INCLUDE:-false}"
PORTS=$(sed -n '/^ports:/,/^[a-z]/p' "$CONFIG" | grep '^\s*-' | strip_comment | sed 's/^\s*-\s*//' | trim)
ISO_NAME=$(grep -A3 '^iso:' "$CONFIG" | grep 'name:' | strip_comment | sed 's/.*://' | trim)
ISO_NAME="${ISO_NAME:-neoos-custom-build}"

echo "== neoos-os-builder =="
echo "kernel: $KERNEL_REF   tests.include: $TESTS_INCLUDE   ports: $(echo "$PORTS" | tr '\n' ' ')"

org=https://github.com/NeoOSOrganization
git clone --depth 1 --branch "$KERNEL_REF" "$org/neoos-kernel" "$WORK/neoos-kernel" 2>&1 | tail -1
git clone --depth 1 "$org/neoos-libneoos" "$WORK/neoos-libneoos" 2>&1 | tail -1
git config --global protocol.git.allow always
git clone --depth 1 "$org/neoos-musl" "$WORK/neoos-musl" 2>&1 | tail -1
(cd "$WORK/neoos-musl" && git submodule update --init upstream)

echo "-- building neoos-libneoos --"
(cd "$WORK/neoos-libneoos" && make)
echo "-- building neoos-musl --"
(cd "$WORK/neoos-musl" && make KERNEL_SHIM_DIR="$WORK/neoos-kernel/third_party/shim")

EMBED_DIRS=""
PORT_DIRS=""

if [ "$TESTS_INCLUDE" = "true" ]; then
    echo "-- building neoos-kernel-tests-common (tests.include: true) --"
    git clone --depth 1 "$org/neoos-kernel-tests-common" "$WORK/neoos-kernel-tests-common" 2>&1 | tail -1
    (cd "$WORK/neoos-kernel-tests-common" && make \
        LIBNEOOS_DIR="$WORK/neoos-libneoos/build-output" \
        MUSL_DIR="$WORK/neoos-musl/build-output")
    EMBED_DIRS="$EMBED_DIRS $WORK/neoos-kernel-tests-common/build"
fi

# Ports install as real disk files, not via embedfs -- see
# docs/superpowers/specs/2026-09-06-os-builder-port-install-design.md
# in neoos-kernel. EMBED_DIRS stays reserved for the regression suite
# above: a port is something a user chooses to have available, not
# something that should auto-run at boot.
for port in $PORTS; do
    echo "-- building neoos-$port --"
    git clone --depth 1 --recurse-submodules "$org/neoos-$port" "$WORK/$port" 2>&1 | tail -1
    (cd "$WORK/$port" && make MUSL_DIR="$WORK/neoos-musl/build-output")
    PORT_DIRS="$PORT_DIRS $port=$WORK/$port/build"
done

echo "-- building neoos-kernel + assembling image (EMBED_DIRS:$EMBED_DIRS PORT_DIRS:$PORT_DIRS) --"
(cd "$WORK/neoos-kernel" && make \
    LIBNEOOS_DIR="$WORK/neoos-libneoos/build-output" \
    MUSL_DIR="$WORK/neoos-musl/build-output" \
    EMBED_DIRS="$EMBED_DIRS" \
    PORT_DIRS="$PORT_DIRS" \
    iso disk-image)

mkdir -p build
cp "$WORK/neoos-kernel/build/neoos.iso" "build/$ISO_NAME.iso"
cp "$WORK/neoos-kernel/build/disk.img" "build/disk1.img"
cp "$WORK/neoos-kernel/build/disk2.img" "build/disk2.img"

cat > "build/metadata.json" <<EOF
{
  "kernel_ref": "$KERNEL_REF",
  "tests_included": $TESTS_INCLUDE,
  "ports": "$(echo "$PORTS" | tr '\n' ',' | sed 's/,$//')",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

sed "s/@ISO@/$ISO_NAME.iso/" scripts/qemu-run.sh.template > build/qemu-run.sh
chmod +x build/qemu-run.sh

echo "OK: build/$ISO_NAME.iso"
