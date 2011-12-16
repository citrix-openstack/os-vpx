#!/bin/sh

set -eux

thisdir=$(dirname "$0")

config="$thisdir/os-vpx.cfg"
cfg=$(basename "$config" .cfg)

rm -rf /obj/os-vpx-orig
rm -rf /obj/os-vpx-devel

# If DEVEL_ONLY is set, then we're going work within /obj/os-vpx, because
# we don't need to keep it pristine.  Otherwise, we're going to copy
# os-vpx to os-vpx-orig and then move it back later, so that we end up with
# a pristine os-vpx and an updated os-vpx-devel.
if [ "${DEVEL_ONLY-no}" != "yes" ]
then
  cp -a /obj/os-vpx /obj/os-vpx-orig

  cleanup()
  {
    rm -rf /obj/os-vpx
    mv /obj/os-vpx-orig /obj/os-vpx
  }
  trap cleanup EXIT
fi

MOCK="mock -r $cfg --resultdir=/tmp/mock-logs"

# We need to clear out /etc/yum because it confuses the package installation
# below.  yum will only be present if we're using QUICK=yes, DEVEL_ONLY=yes.
$MOCK --chroot "rm -rf /etc/yum*"
$MOCK --chroot "mkdir /etc/yum"
root=$($MOCK --print-root-path)
(echo 'config_opts={"plugin_conf":{}}'
 cat os-vpx.cfg
 echo "print config_opts['yum.conf']") | python - >"$root/etc/yum/yum.conf"

$MOCK --install "file"
$MOCK --install "nfs-utils"
$MOCK --install "screen"
$MOCK --install "gdb"
$MOCK --install "tcpdump"
$MOCK --install "vim-enhanced"

$MOCK --install "yum"
$MOCK --chroot "if [ -f /etc/yum.conf.rpmnew ] ; then mv /etc/yum.conf{.rpmnew,} ; fi"
$MOCK --chroot "rm -f /etc/yum/yum.conf"

(cd "$thisdir/overlay-devel"
 find * -type d -print0 | \
    xargs -0 -i__dir__ $MOCK --chroot "mkdir -p /__dir__"
 find * -type f -a \! -name '.*' -print0 | \
    xargs -0 -i__file__ $MOCK --copyin "$thisdir/overlay-devel/__file__" "/__file__"
)

$MOCK --chroot "chmod u=rwx,go=rx /usr/bin/os-vpx-*"
$MOCK --chroot "cp /root/.ssh/{id_rsa.pub,authorized_keys}"
$MOCK --chroot "chmod u=rwx,go=rx /root/.ssh"
$MOCK --chroot "chmod u=rw,go= /root/.ssh/authorized_keys"
$MOCK --chroot "chmod u=rw,go= /root/.ssh/config"
$MOCK --chroot "chmod u=rw,go= /root/.ssh/id_rsa"

if [ "${DEVEL_ONLY-no}" = "yes" ]
then
  ln -s /obj/os-vpx /obj/os-vpx-devel
else
  mv /obj/os-vpx /obj/os-vpx-devel
fi
