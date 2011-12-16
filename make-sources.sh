#!/bin/sh

set -eu

output="$1"
version="$2"

thisdir=$(dirname "$0")

tmp=$(mktemp -d)

cleanup()
{
  rm -rf "$tmp"
}
trap cleanup EXIT

MOCK="mock -r os-vpx --resultdir=/tmp/mock-logs"

srpms=$($MOCK --shell "rpm -qa --queryformat '%{SOURCERPM}\n'")

dirs=$(sed -ne 's,^baseurl=file://\(.*\)$,\1,p' "$thisdir/os-vpx.cfg")

for srpm in $srpms
do
  if [ -f "$tmp/$srpm" ]
  then
    continue
  fi
  for d in $dirs
  do
    f=$(readlink -f "$d/$srpm" || true)
    if [ -f "$f" ]
    then
      echo "Using $f"
      cp -s "$f" "$tmp/$srpm"
      break
    fi
    f=$(readlink -f "$d/SRPMS/$srpm" || true)
    if [ -f "$f" ]
    then
      echo "Using $f"
      cp -s "$f" "$tmp/$srpm"
      break
    fi
    f=$(readlink -f "$d/../SRPMS/$srpm" || true)
    if [ -f "$f" ]
    then
      echo "Using $f"
      cp -s "$f" "$tmp/$srpm"
      break
    fi
  done
done

for srpm in $srpms
do
  if [ ! -f "$tmp/$srpm" ]
  then
    echo "Couldn't find source for $srpm" >&2
    exit 1
  fi
done

eggs=$($MOCK --shell "find /usr/lib/python2.6/site-packages -name *.egg*")

for egg in $eggs
do
  rpm=$($MOCK --shell "rpm -qf $egg" 2>/dev/null || true)
  if ! expr "$rpm" : ".*not owned" >/dev/null
  then
    # This will be provided by an RPM -- skip it.
    echo "$egg is owned by an RPM"
    continue
  fi
  e=$(basename "$egg" -info)
  f=$(find /distfiles/python -name $e)
  if [ -f "$f" ]
  then 
    echo "Using $f"
    cp -s "$f" "$tmp/$e"
    continue
  fi
  echo "Cannot find source for $egg"
  exit 1
done

mkdir -p $(dirname "$output")
mkisofs -joliet -joliet-long -r -f -V "OpenStack $version source" \
        -o "$output" "$tmp"
