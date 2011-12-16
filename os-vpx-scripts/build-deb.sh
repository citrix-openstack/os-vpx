#!/bin/sh

set -eux

dest="$1"

thisdir=$(dirname $(readlink -f "$0"))
cd "$thisdir"

dirs=usr

brand()
{
  local src="$1"
  local dst="$2"
  sed -e "s,@PRODUCT_VERSION@,$PRODUCT_VERSION,g" \
      -e "s,@BUILD_NUMBER@,$BUILD_NUMBER,g" "$src" >"$dst"
}

src=$(find "$dirs" -type f \
          -a \! -name '*~' \
          -a \! -name '*.flc' \
          -a \! -name '*.orig' \
          -a \! -name '*.rej' \
          -print)

tmpdir=$(mktemp -d --tmpdir=$MY_OBJ_DIR)
cleanup()
{
  rm -rf "$tmpdir"
}
trap cleanup EXIT

build_date=$(date -u '+%Y-%m-%d %T %Z')

mkdir -p "$tmpdir/DEBIAN"
cp -a --parents $src "$tmpdir"
cat <<EOF >"$tmpdir/usr/share/os-vpx/inventory"
OS_VPX_PRODUCT_VERSION='$PRODUCT_VERSION'
OS_VPX_BUILD_NUMBER='$BUILD_NUMBER'
OS_VPX_BUILD_DATE='$build_date'
EOF

brand "control.in" "$tmpdir/DEBIAN/control"
fakeroot chown -R root:root "$tmpdir"
find "$tmpdir" -type f | xargs fakeroot chmod a-x
fakeroot chmod -R u=rwX,go=rX "$tmpdir"
fakeroot chmod -R u=rwx,go=rx "$tmpdir/usr/bin/os-vpx-"*
mkdir -p $(dirname "$dest")
fakeroot dpkg-deb --build "$tmpdir" "$dest"
