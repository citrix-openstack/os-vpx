#!/bin/bash

# This script may get invoked either during OS
# install time or post-install time depending
# on when the openstack supplemental pack is
# installed. If invoked during OS install time,
# it copies over a script that will create a
# Local ISO storage SR, into firstboot.d/.
# If invoked after install time, it will
# install the same script into /opt/xensource/bin/.

# If xapi is up and running, we assume this is
# post OS installation. If otherwise, this is
# being invoked during OS installation. 

thisdir=$(dirname "$0")

# Pre-installation step: this runs before first reboot
if ! pidof /opt/xensource/bin/xapi >/dev/null
then
  echo "Placing script to create Local ISO SR in firstboot"
  cp "$thisdir/64-xs-create-iso-sr" /etc/firstboot.d
  chmod a+x /etc/firstboot.d/64-xs-create-iso-sr
  exit 0
fi

# Else, this is post OS install.
# Restart xapi, and run the xs-create-iso-sr script
# explicitly. We are restarting xapi because before
# invoking this script in the xenserver-openstack
# spec file, we copied over a new file LocalISOSR.py
# into /opt/xensource/sm, and created a link to it
# in the same directory. We need to restart xapi for
# it to load in this new module.
service xapi restart
# Ensure xapi starts up fully.
while [ 1 ]; do
  uuid=`xe pool-list --minimal params=master`
  res=`xe host-list --minimal params=enabled uuid=$uuid`
  if [ "$res" != 'true' ]; then
    sleep 1;
  else
    break
  fi
done
/opt/xensource/bin/xs-create-iso-sr
rc=$?
if [ $rc -ne 0 ]; then
  echo "Error encountered when trying to create ISO SR"
else
  echo "Successfully created ISO SR"
fi
exit $rc
