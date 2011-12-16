#!/bin/bash

set -eu

# If config is non-empty, we're building CentOS chroot using Mock.
# If it's empty, then we're building Ubuntu chroot using debootstrap, and
# staging should be set instead.
#
# Yes this is horrible: it will go away soon.
config="$1"
version="$2"
staging="${3-}"
shift 2
shift || true
debs="${@-}"

thisdir=$(readlink -f $(dirname "$0"))

cfg=$(basename "$config" .cfg)

MOCK="mock -r $cfg --resultdir=/tmp/mock-logs"

export LANG=C

copyin()
{
  echo chroot: ${1/$thisdir\//} '->' $2
  if [ "$config" ]
  then
    $MOCK --copyin "$1" "$2"
  else
    cp "$1" "$staging/$2"
  fi
}

chrootit()
{
  echo chroot: $@
  if [ "$config" ]
  then
    $MOCK --chroot "$@"
  else
    chroot "$staging" sh -c "$*"
  fi
}

chkconfig_on()
{
  if [ "$config" ]
  then
    chrootit "chkconfig --add $1"
    chrootit "chkconfig $1 on"
  else
    chrootit "update-rc.d $1 defaults"
  fi
}

install_debs()
{
  local debs="$@"
  local ds=
  for deb in $debs
  do
    copyin "$deb" /
    ds="$ds $(basename $deb)"
  done
  if [ "$ds" ]
  then
    chrootit "dpkg -i $ds"
    chrootit "rm $ds"
  fi
}

install_debs "$debs"

copyin "$thisdir/XenAPI.py" /usr/lib/python2.6
(cd "$thisdir/overlay"
 find * -type d -print0 | \
    while read -d $'\0' i ; do chrootit "mkdir -p /$i" ; done
 find * -type f -a \( -name '.bash_profile' -o \! -name '.*' \) -print0 | \
    while read -d $'\0' i ; do copyin "$thisdir/overlay/$i" "/$i" ; done
)

if [ "$config" ]
then
  patch -d "/obj/os-vpx/root" -p0 <"$thisdir/udev-xvd.patch"
fi

# Dump vpx-version in /etc and link it to /etc/openstack/vpx-version
# This extra level of indirection is required to preserve the correct
# vpx-version across vpx upgrades where the state disk is retained.
# To avoid the indirection, geppetto/hapi/config_util.py could use 
# the /etc/vpx-version directly, but it's nice to know we can look 
# only in one place.
chrootit "echo VPX_VERSION=$version >/etc/vpx-version"
chrootit "rm -f /etc/openstack/vpx-version"
chrootit "ln -s /etc/vpx-version /etc/openstack/vpx-version"

chrootit "chmod u=rwx,go=rx /etc/init.d/firstboot"
chkconfig_on firstboot
chrootit "chmod u=rwx,go=rx /etc/firstboot.d/*"
chrootit "mkdir -p /etc/firstboot.d/data"
chrootit "mkdir -p /etc/firstboot.d/state"
chrootit "mkdir -p /etc/firstboot.d/log"

chkconfig_on dnsmasq
chkconfig_on rsyslog
chkconfig_on citrix-esx-geppetto-network

# OS-305-BEGIN 
# This is experimental and needs to be removed at some point
chrootit "chmod u=rwx,go=rx /etc/init.d/openstack-lb-service"
chrootit "chkconfig --add openstack-lb-service"
chrootit "chmod u=rwx,go=rx /usr/bin/lbservice"
# OS-305-END

chrootit "chmod u=r,g=r,o-r /etc/sudoers"
chrootit "chmod u=rw,go=r /etc/crontab"
if [ "$config" ]
then
  chrootit "chmod u=rwx,go=rx /usr/bin/os-vpx-*"
fi
# Add here the OpenStack CLI tools' wrappers
# Nova
chrootit "chmod u=rwx,go=rx /usr/local/bin/nova"
chrootit "chmod u=rwx,go=rx /usr/local/bin/nova-manage"
chrootit "chmod u=rwx,go=rx /usr/local/bin/nova-dhcpbridge"
# Glance
chrootit "chmod u=rwx,go=rx /usr/local/bin/glance"
chrootit "chmod u=rwx,go=rx /usr/local/bin/glance-manage"
chrootit "chmod u=rwx,go=rx /usr/local/bin/glance-upload"
# Swift
chrootit "chmod u=rwx,go=rx /usr/local/bin/swift"

chrootit "chmod u=rwx,go=rx /usr/local/bin/mysql"

chrootit "chmod u=rwx,go=rx /usr/local/bin/xe"

fstab_entry()
{
  local dev="$1"
  local mp="$2"
  local rest="$3"
  chrootit "grep -v $mp /etc/fstab >/etc/fstab.tmp"
  chrootit "echo '$dev $mp $rest' >>/etc/fstab.tmp"
  chrootit "mv /etc/fstab.tmp /etc/fstab"
}

fstab_entry "/dev/cdrom" "/media/cdrom" "auto defaults,ro,noauto 0 0"
chrootit "mkdir -p /media/cdrom"

chrootit "mkdir -p /state"

chrootit "rm -rf /var/cache/yum/*"
