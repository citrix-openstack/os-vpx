#!/bin/sh

set -eu

packages="$@"

thisdir=$(dirname "$0")

rm -f "$thisdir/deps.dot"
for p in $packages
do
  "$thisdir/rpmdep.pl" -dot "$thisdir/dep.dot" "$p"
  (if grep -q ';' "$thisdir/dep.dot"
   then
     grep ';' "$thisdir/dep.dot"
   else
     echo "${p/-/_} -> basesystem;"
   fi) >>"$thisdir/deps.dot"
done
