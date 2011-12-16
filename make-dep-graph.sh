#!/bin/sh

set -eu

dest="$1"
packages_list="$2"

thisdir=$(dirname "$0")

tmp=$(mktemp -d)
chmod a=rwx "$tmp"

cleanup()
{
  rm -rf "$tmp"
}
trap cleanup EXIT

get_conf()
{
  (echo 'config_opts={"plugin_conf":{}}'
   cat "$thisdir/os-vpx.cfg"
   echo "print config_opts['$1']") | python
}

cmd=$(get_conf 'chroot_setup_cmd')
packages="${cmd/install /}"

MOCK="mock -r os-vpx --resultdir=/tmp/mock-logs"

$MOCK --chroot "rm -rf /tmp/rpmorphan"
$MOCK --copyin "$thisdir/rpmorphan" "/tmp/rpmorphan"
$MOCK --copyin "$thisdir/make-dep-graph-2.sh" "/tmp/rpmorphan"
$MOCK --chroot "sh /tmp/rpmorphan/make-dep-graph-2.sh $packages"
$MOCK --copyout "/tmp/rpmorphan/deps.dot" "$tmp/deps.dot"
$MOCK --chroot "rm -rf /tmp/rpmorphan"

echo "digraph \"G\" {" >"$dest"
cat "$tmp/deps.dot" | sort | uniq >>"$dest"
echo "}" >>"$dest"

$MOCK --chroot "rpm -qa | sort >/tmp/packages-list"
$MOCK --copyout "/tmp/packages-list" "$tmp/packages-list"
$MOCK --chroot "rm -f /tmp/packages-list"
mv "$tmp/packages-list" "$packages_list"
