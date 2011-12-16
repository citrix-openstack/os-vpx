#!/bin/sh

set -eux

config="$1"
nova_repo="$2"
glance_repo="$3"
swift_repo="$4"
keystone_repo="$5"
geppetto_repo="$6"

cfg=$(basename "$config" .cfg)

MOCK="mock -r $cfg --resultdir=/tmp/mock-logs"

# Note that easy_install-nova-deps.sh copies the eggs into the chroot, so we
# don't have to.

sh "$nova_repo/easy_install-nova-deps.sh" "$MOCK"
sh "$glance_repo/easy_install-glance-deps.sh" "$MOCK"
sh "$swift_repo/easy_install-swift-deps.sh" "$MOCK"
sh "$keystone_repo/easy_install-keystone-deps.sh" "$MOCK"
sh "$geppetto_repo/easy_install-geppetto-deps.sh" "$MOCK"

$MOCK --chroot "rm -rf /eggs"
