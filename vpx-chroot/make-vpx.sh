#!/bin/sh

set -ex

stagingdir="$1"
config="$2"

thisdir=$(dirname "$0")

cfg=$(basename "$config" .cfg)

MOCK="mock -vvv -r $cfg --resultdir=/tmp/mock-logs"
TO_RM="/usr/lib/locale /usr/share/locale /usr/share/i18n/locales /usr/share/zoneinfo /usr/share/anaconda /usr/share/cracklib /usr/share/doc /usr/share/info /usr/share/man /usr/share/pixmaps"

if [ "${QUICK-no}" = "yes" ] && [ -d "$stagingdir" ]
then
    echo "Skipping chroot rebuild -- QUICK=yes."
    exit
fi

rm -rf "$stagingdir"
rm -rf /tmp/mock-logs
rm -f /etc/mock/$(basename "$config")
cp "$config" /etc/mock
if ! grep -q "VPX patch" /usr/lib/python2.4/site-packages/mock/backend.py
then
    patch -d / -p0 <"$thisdir/mock.patch"
fi
$MOCK --init
kernel_version=$($MOCK --shell 'rpm -qv kernel-xen' | sed -e 's/kernel-xen-//g')
$MOCK --copyin "$thisdir/menu.lst" /boot/grub/menu.lst
$MOCK --chroot "sed -e 's,@KERNEL_VERSION@,$kernel_version,g' -i /boot/grub/menu.lst"
$MOCK --copyin "$thisdir/fstab" /etc/fstab
$MOCK --copyin "$thisdir/sysconfig_network" /etc/sysconfig/network
$MOCK --copyin "$thisdir/ifcfg-eth0" /etc/sysconfig/network-scripts/ifcfg-eth0
$MOCK --copyin "$thisdir/ifcfg-eth1" /etc/sysconfig/network-scripts/ifcfg-eth1
patch -d "$stagingdir/root" -p0 <"$thisdir/inittab.patch"
patch -d "$stagingdir/root" -p0 <"$thisdir/securetty.patch"
$MOCK --chroot "mkinitrd /boot/initrd-${kernel_version}xen.img ${kernel_version}xen -f -v --with xennet --with xenblk --preload xennet --preload xenblk"
# mkinitrd for the non-xen kernel if present
$MOCK --chroot "test -f /boot/initrd-${kernel_version}.img && mkinitrd /boot/initrd-${kernel_version}.img ${kernel_version} -f -v --with ata_piix --with mptbase --with mptscsih --with mptspi --with scsi_mod --with scsi_transport_spi --with sd_mod"
# Put the VPX into UTC.
$MOCK --chroot "rm -f /etc/localtime"
# Delete loads of stuff that we don't need.
$MOCK --chroot "rm -R $TO_RM"
# Make a small cracklib dictionary, so that passwd still works, but we don't
# have the big dictionary.
$MOCK --chroot "mkdir /usr/share/cracklib"
$MOCK --chroot "echo a | cracklib-packer"
# Make /etc/shadow, and set the root password to "citrix".
$MOCK --chroot "pwconv"
echo "root:citrix" | $MOCK --shell "chpasswd"
patch -d / -p0 -R <"$thisdir/mock.patch"
