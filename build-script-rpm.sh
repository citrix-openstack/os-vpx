#!/bin/sh

set -ex

spec="$1"
srcdir="$2"
dest_rpm="$3"

thisdir=$(dirname "$0")

cfg=$(basename "$spec" .spec)
config="$srcdir/$cfg.cfg"

arch=$(basename "$dest_rpm" .rpm)
arch=$(echo "$arch" | sed -e 's/^.*\.//')

dest_rpm_dir=$(dirname "$dest_rpm")
dest_srpm_dir="${dest_rpm_dir/RPMS\/$arch/SRPMS}"

dest_srpm_file=$(basename "$dest_rpm")
dest_srpm_file="${dest_srpm_file/$arch/src}"

if [ "${QUICK-no}" = "yes" ]
then
  tempdir=/tmp/quick-build
  mkdir -p "$tempdir"
else
  tempdir=$(mktemp -d)
fi
chmod a=rwx "$tempdir"

cleanup()
{
  rm -rf "/obj/$cfg"
  rm -rf "$tempdir"
  rm -f "/etc/mock/$cfg.cfg"
}

if [ "${QUICK-no}" != "yes" ]
then
  # To prevent cleanup, comment out the next line.
  trap cleanup EXIT
fi

MOCK="mock -vvv -r $cfg --resultdir=$tempdir"

mkdir -p "$dest_rpm_dir"
mkdir -p "$dest_srpm_dir"
cp -f "$config" /etc/mock

mkdir -p "$tempdir/SOURCES"
tar -C "$srcdir" . -czf "$tempdir/SOURCES/source.tar.gz" \
    --exclude *~

if [ "${QUICK-no}" != "yes" ] || [ ! -d "/obj/$cfg" ]
then
  $MOCK --init
fi

$MOCK --no-clean --no-cleanup-after --buildsrpm --spec "$spec" \
      --sources "$tempdir/SOURCES"
$MOCK --no-clean --no-cleanup-after --rebuild --target="$arch" \
      "$tempdir/$dest_srpm_file"

mv "$tempdir/"*.src.rpm "$dest_srpm_dir"
mv "$tempdir/"*.rpm "$dest_rpm_dir"

createrepo $(dirname "$dest_srpm_dir")
