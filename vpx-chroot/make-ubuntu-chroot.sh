#!/bin/sh

set -eu

UBUNTU_VERSION="natty"
UBUNTU_MIRROR="us.archive.ubuntu.com/ubuntu"
UBUNTU_SECURITY="security.ubuntu.com/ubuntu"
APT_CACHE_URL="http://apt:3142/$UBUNTU_MIRROR"

PAE_KERNEL_VERSION="2.6.38-11-generic-pae"
VIRT_KERNEL_VERSION="2.6.38-11-virtual"

ROOT_PASSWORD='citrix'

staging_dir="$1"
packages_file="$2"

thisdir=$(readlink -f $(dirname "$0"))

mkdir -p "$staging_dir"

cleanup()
{
  # These often get left mounted by debootstrap, if you interrupt it.
  umount "$staging_dir/proc" || true
  umount "$staging_dir/sys" || true
}
trap cleanup EXIT


export LANG=C
export DEBIAN_FRONTEND=noninteractive

if [ ! -d "$staging_dir/root" ]
then
  debootstrap "$UBUNTU_VERSION" "$staging_dir" "$APT_CACHE_URL"
fi

chroot "$staging_dir" sh -c 'cat >/etc/apt/sources.list' <<EOF
deb "http://$UBUNTU_MIRROR" natty main restricted
deb "http://$UBUNTU_MIRROR" natty-updates main restricted
deb "http://$UBUNTU_MIRROR" natty universe
deb "http://$UBUNTU_MIRROR" natty-updates universe
deb "http://$UBUNTU_SECURITY" natty-security main restricted
deb "http://$UBUNTU_SECURITY" natty-security universe
EOF

chroot "$staging_dir" sh -c 'cat >/etc/apt/apt.conf.d/02proxy' <<EOF
Acquire::http { Proxy "http://apt:3142"; };
EOF

chroot "$staging_dir" apt-get update
chroot "$staging_dir" apt-get --no-install-recommends -y dist-upgrade

# Move initctl out of the way, so that packages can't start any services
# even if they try to.
if [ ! -L "$staging_dir/sbin/initctl" ]
then
  chroot "$staging_dir" dpkg-divert --local --rename --add /sbin/initctl
  chroot "$staging_dir" ln -s /bin/true /sbin/initctl
fi

install="chroot $staging_dir apt-get --no-install-recommends -y install"
$install \
  "linux-image-$PAE_KERNEL_VERSION" \
  "linux-image-$VIRT_KERNEL_VERSION" \
  grub \
  cracklib-runtime
awk "
/^!/ { print \"$install\" packs; packs=\"\"; printf(\"chroot $staging_dir sh -eu -c '%s'\\n\", substr(\$0, 2)) }
/^[^#!]/ { packs = packs \" \" \$0 }
END { print \"$install\" packs }
" "$packages_file" | sh -eux

# Put initctl back.
if [ -L "$staging_dir/sbin/initctl" ]
then
  chroot "$staging_dir" rm /sbin/initctl
  chroot "$staging_dir" dpkg-divert --local --rename --remove /sbin/initctl
fi

chroot "$staging_dir" apt-get autoremove
chroot "$staging_dir" apt-get clean

# Setup interfaces, fstab, tty, and other system stuff
cp "$thisdir/fstab" "$staging_dir/etc/fstab"
cp "$thisdir/interfaces" "$staging_dir/etc/network/interfaces"
cp "$thisdir/hvc0.conf" "$staging_dir/etc/init/"

# Put the VPX into UTC.
rm -f "$staging_dir/etc/localtime"

# Make a small cracklib dictionary, so that passwd still works, but we don't
# have the big dictionary.
mkdir -p "$staging_dir/usr/share/cracklib"
echo a | chroot "$staging_dir" cracklib-packer

echo 'localhost' >"$staging_dir/etc/hostname"

# Make /etc/shadow, and set the root password.
chroot "$staging_dir" pwconv
echo "root:$ROOT_PASSWORD" | chroot "$staging_dir" chpasswd
