#!/bin/sh

set -eu

thisdir=$(dirname "$0")

# Pre-installation step: this runs before first reboot
if ! pidof /opt/xensource/bin/xapi >/dev/null
then
  echo "Saving import of OpenStack VPX until next boot."
  cp "$thisdir/65-install-os-vpx" /etc/firstboot.d
  chmod a+x /etc/firstboot.d/65-install-os-vpx
  exit 0
fi

# Installation step: this runs at firstboot
CMD_ARGS="-i"
# Fetch configuration, if available (only for PXE installations)
OS_VPX_CONFIG=/opt/xensource/packages/files/os-vpx/os-vpx-config
if [ -f "$OS_VPX_CONFIG" ]
then
  VPX_CONF=$(wget -q $(cat "$OS_VPX_CONFIG") -O-)
  CMD_ARGS="${CMD_ARGS} $VPX_CONF"
fi 

# Install the VPX
eval $thisdir/install-os-vpx.sh $CMD_ARGS
