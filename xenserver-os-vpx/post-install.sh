#!/bin/sh

echo Starting post-install script

# Detect the root disk with fdisk (might have a dell utility partition first)
boot=`fdisk -l /dev/sda | sed -e '/^\/dev\/.*\*/!d;s/ .*//'`

echo Detected boot device as ${boot}

# Mount the root filesystem
mkdir -p /tmp/root
mount ${boot} /tmp/root

# os-vpx-config is a text file that contains command args to be passed to the install-os-vpx.sh script
# e.g. $cat os-vpx-config
#       $-m <bridge> -p <bridge> -r <ram> -d <data-disk-size>
# only -m, -p, -r, or -d can be specified.
echo "<put here the URL to your os-vpx-config" >/tmp/root/opt/xensource/packages/files/os-vpx/os-vpx-config

umount /tmp/root
exit 0
