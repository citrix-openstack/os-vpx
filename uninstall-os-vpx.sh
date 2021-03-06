#!/bin/sh

remove_data=
if [ "$1" = "--remove-data" ]
then
  remove_data=1
fi

set -eu

xe_min()
{
  local cmd="$1"
  shift
  /opt/xensource/bin/xe "$cmd" --minimal "$@"
}

destroy_vdi()
{
  local vbd_uuid="$1"
  local type=$(xe_min vbd-list uuid=$vbd_uuid params=type)
  local dev=$(xe_min vbd-list uuid=$vbd_uuid params=userdevice)
  local vdi_uuid=$(xe_min vbd-list uuid=$vbd_uuid params=vdi-uuid)

  if [ "$type" = 'Disk' ] && [ "$dev" != 'xvda' ] && [ "$dev" != '0' ]
  then
    echo -n "Destroying data disk... "
    xe vdi-destroy uuid=$vdi_uuid
    echo "done."
  fi
}

uninstall()
{
  local vm_uuid="$1"
  local power_state=$(xe_min vm-list uuid=$vm_uuid params=power-state)

  if [ "$power_state" != "halted" ]
  then
    echo -n "Shutting down VM... "
    xe vm-shutdown vm=$vm_uuid force=true
    echo "done."
  fi

  if [ "$remove_data" = "1" ]
  then
    for v in $(xe_min vbd-list vm-uuid=$vm_uuid | sed -e 's/,/ /g')
    do
      destroy_vdi "$v"
    done
  fi

  echo -n "Deleting VM... "
  xe vm-uninstall vm=$vm_uuid force=true >/dev/null
  echo "done."
}

uninstall_template()
{
  local vm_uuid="$1"

  if [ "$remove_data" = "1" ]
  then
    for v in $(xe_min vbd-list vm-uuid=$vm_uuid | sed -e 's/,/ /g')
    do
      destroy_vdi "$v"
    done
  fi

  echo -n "Deleting template... "
  xe template-uninstall template-uuid=$vm_uuid force=true >/dev/null
  echo "done."
}


for u in $(xe_min vm-list other-config:os-vpx=true | sed -e 's/,/ /g')
do
  uninstall "$u"
done

for u in $(xe_min template-list other-config:os-vpx=true | sed -e 's/,/ /g')
do
  uninstall_template "$u"
done
