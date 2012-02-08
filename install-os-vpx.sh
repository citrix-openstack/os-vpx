#!/bin/bash

set -eu

. /etc/xensource-inventory

NAME="XenServer OpenStack VPX"
DATA_VDI_SIZE="500MiB"
DATA_DISK_VDI=
BRIDGE_M=
BRIDGE_P=
BRIDGE_G=
KERNEL_PARAMS=
VPX_FILE=os-vpx.xva
AS_TEMPLATE=
FROM_TEMPLATE=
TEMPLATE_LABEL=
RAM=
WAIT_FOR_NETWORK=
BALLOONING=
OTHER_CONFIGS=

usage()
{
cat << EOF

  Usage: $0 [-i|-c LABEL] [-f FILE_PATH] [-d DISK_SIZE] [-m BRIDGE_NAME] [-p BRIDGE_NAME] [-k PARAMS]
            [-r RAM] [-w] [-b] [-l TEMPLATE_LABEL] [-a DISK_VDI_UUID] [-o OTHER_CONFIGS]

  Installs XenServer OpenStack VPX.

  OPTIONS:

     -h           Shows this message.
     -b           Enable memory ballooning. When set min_RAM=RAM/2 max_RAM=RAM.
     -c label     Clone from existing template named 'label'.
     -i           Install OpenStack VPX as template.
     -w           Wait for the network settings to show up before exiting.

     -a vdi-uuid  VDI of data disk to be attached (Must not be in use).
                  Without this flag, the installer attaches any pre-existing data
                  disk (if unique and not in use), otherwise it creates a new
                  data disk.
     -d disk-size Size for the data disk, in MiB.
                  Defaults to 500 MiB.
     -k params    Kernel parameters.
     -l label     Label to template, when -i is specified.
     -f path      Path to the XVA.
                  Default to ./os-vpx.xva.
     -m bridge    Bridge for the isolated management network.
                  Defaults to xenbr0.
     -o configs   other-config kwargs for the VM installed.
                  When -i is specified, kwargs do not get set on the vm template.
     -p bridge    Bridge for the externally facing network.
     -r MiB       RAM used by the VPX, in MiB.
                  Defaults to value from the XVA.

  EXAMPLES:

     Create a VPX that connects to the isolated management network using the
     default bridge with a data disk of 1GiB:
            install-os-vpx.sh -f /root/os-vpx-devel.xva -d 1024

     Create a VPX that connects to the isolated management network using xenbr1
     as bridge:
            install-os-vpx.sh -m xenbr1

     Create a VPX that connects to both the management and public networks
     using xenbr1 and xapi4 as bridges:
            install-os-vpx.sh -m xenbr1 -p xapi4

     Create a VPX that connects to both the management and public networks
     using the default for management traffic:
            install-os-vpx.sh -m xapi4

     Create a VPX that automatically becomes the master:
            install-os-vpx.sh -k geppetto_master=true

     Create a template specifying its name as "Openstack_Master:
            install-os-vpx.sh -l "Openstack_Master"

     Create a VPX with some other-config(s):
            install-os-vpx.sh -o "master=true vpx=true"

EOF
}


get_params()
{
  while getopts "hic:wbf:a:d:m:p:g:k:l:o:r:" OPTION; 
  do
    case $OPTION in
      h) usage
         exit 1
         ;;
      i)
         AS_TEMPLATE=1
         ;;
      c)
         FROM_TEMPLATE=1
         TEMPLATE_LABEL="$OPTARG"
         ;;
      w)
         WAIT_FOR_NETWORK=1
         ;;
      b)
         BALLOONING=1
         ;;
      f)
         VPX_FILE=$OPTARG
         ;;
      d)
         DATA_VDI_SIZE="${OPTARG}MiB"
         ;;
      a)
         DATA_DISK_VDI=${OPTARG}
         ;;
      m)
         BRIDGE_M=$OPTARG
         ;;
      g)
         BRIDGE_G=$OPTARG
         ;;
      p)
         BRIDGE_P=$OPTARG
         ;;
      k)
         KERNEL_PARAMS=$OPTARG
         ;;
      l) 
         TEMPLATE_LABEL="$OPTARG"
         ;;
      o)
         OTHER_CONFIGS="$OPTARG"
         ;;
      r)
         RAM=$OPTARG
         ;;
      ?)
         usage
         exit 1
         ;;
    esac
  done
  if [[ -z $BRIDGE_M ]]
  then
     BRIDGE_M=xenbr0
  fi
}


xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}


show_ip()
{
  ip_addr=$(echo "$1" | sed -n "s,^.*"$2"/ip: \([^;]*\).*$,\1,p")
  echo -n "IP address for $3: "
  if [ "$ip_addr" = "" ]
  then
    echo "did not appear."
  else
    echo "$ip_addr."
  fi
}


get_dest_sr()
{
  IFS=,
  sr_uuids=$(xe sr-list --minimal other-config:i18n-key=local-storage)
  dest_sr=""
  for sr_uuid in $sr_uuids
  do
    pbd=$(xe pbd-list --minimal sr-uuid=$sr_uuid host-uuid=$INSTALLATION_UUID)
    if [ "$pbd" ]
    then
      echo "$sr_uuid"
      unset IFS
      return
    fi
  done
  unset IFS

  dest_sr=$(xe_min sr-list uuid=$(xe_min pool-list params=default-SR))
  if [ "$dest_sr" = "" ]
  then
    echo "No local storage and no default storage; cannot import VPX." >&2
    exit 1
  else
    echo "$dest_sr"
  fi
}


find_network()
{
  result=$(xe_min network-list bridge="$1")
  if [ "$result" = "" ]
  then
    result=$(xe_min network-list name-label="$1")
  fi
  echo "$result"
}


find_template()
{
  local label="$1"
  xe_min template-list name-label="$label"
}


renumber_system_disk()
{
  local v="$1"
  local vdi_uuid=$(xe_min vbd-list vm-uuid="$v" type=Disk userdevice=xvda \
                                   params=vdi-uuid)
  if [ "$vdi_uuid" ]
  then
    local vbd_uuid=$(xe_min vbd-list vm-uuid="$v" vdi-uuid="$vdi_uuid")
    xe vbd-destroy uuid="$vbd_uuid"
    local new_vbd_uuid=$(xe vbd-create vm-uuid="$v" vdi-uuid="$vdi_uuid" \
                         device=0 bootable=true type=Disk)
    xe vbd-param-set other-config:owner uuid="$new_vbd_uuid"
  fi
}


create_vif()
{
  xe vif-create vm-uuid="$1" network-uuid="$2" device="$3"
}


create_gi_vif()
{
  local v="$1"
  # Note that we've made the outbound device eth1, so that it comes up after
  # the guest installer VIF, which means that the outbound one wins in terms
  # of gateway.
  if [[ -n $BRIDGE_G ]]
  then
    local gi_network_uuid=$(xe_min network-list bridge=$BRIDGE_G)
  else
    local gi_network_uuid=$(xe_min network-list \
                                 other-config:is_guest_installer_network=true)
  fi
  create_vif "$v" "$gi_network_uuid" "0" >/dev/null
}


create_management_vif()
{
  local v="$1"
  echo "Installing management interface on $BRIDGE_M."
  local out_network_uuid=$(find_network "$BRIDGE_M")
  create_vif "$v" "$out_network_uuid" "1" >/dev/null
}


# This installs the interface for public traffic, only if a bridge is specified
# The interface is not configured at this stage, but it will be, once the admin   
# tasks are complete for the services of this VPX
create_public_vif()
{
  local v="$1"
  if [[ -z $BRIDGE_P ]]
  then
    echo "Skipping installation of interface for public traffic."
  else
    echo "Installing public interface on $BRIDGE_P."
    pub_network_uuid=$(find_network "$BRIDGE_P")
    create_vif "$v" "$pub_network_uuid" "2" >/dev/null
  fi
}


label_system_disk()
{
  local v="$1"
  local vdi_uuid=$(xe_min vbd-list vm-uuid="$v" type=Disk userdevice=0 \
                                   params=vdi-uuid)
  xe vdi-param-set \
     name-label="$NAME system disk" \
     other-config:os-vpx=true \
     uuid=$vdi_uuid
}


clear_data_config()
{
  local v="$1"
  IFS=,
  for vbd_uuid in $(xe_min vbd-list vm-uuid="$v" params=uuid)
  do
    xe vbd-param-clear uuid="$vbd_uuid" param-name=other-config
    vdi_uuid=$(xe_min vdi-list vbd-uuids="$vbd_uuid" params=uuid)
    if [ "$vdi_uuid" != "" ]
    then
      xe vdi-param-clear uuid="$vdi_uuid" param-name=other-config
    fi
  done
  unset IFS
}


create_data_disk()
{
  local v="$1"
  local data_vdi_uuid="$DATA_DISK_VDI"
  local data_in_use=""

  local sys_vdi_uuid=$(xe_min vbd-list vm-uuid="$v" type=Disk params=vdi-uuid)
  if [ "$data_vdi_uuid" ]
  then
    echo "Attaching data disk from vdi: $data_vdi_uuid"
    data_in_use=$(xe_min vbd-list vdi-uuid="$data_vdi_uuid")
  else
    data_vdi_uuid=$(xe_min vdi-list other-config:os-vpx-data=true)
    if echo "$data_vdi_uuid" | grep -q ,
    then
      echo "Multiple data disks found -- assuming that you want a new one."
      data_vdi_uuid=""
    else
      data_in_use=$(xe_min vbd-list vdi-uuid="$data_vdi_uuid")
    fi
  fi
  if [ "$data_in_use" != "" ]
  then
     echo "Data disk already in use -- will create another one."
     data_vdi_uuid=""
  fi

  if [ "$data_vdi_uuid" = "" ]
  then
    echo -n "Creating new data disk ($DATA_VDI_SIZE)... "
    sr_uuid=$(xe_min vdi-list params=sr-uuid uuid="$sys_vdi_uuid")
    data_vdi_uuid=$(xe vdi-create name-label="$NAME data disk" \
                                  sr-uuid="$sr_uuid" \
                                  type=user \
                                  virtual-size="$DATA_VDI_SIZE")
    xe vdi-param-set \
       other-config:os-vpx-data=true \
       uuid="$data_vdi_uuid"
    dom0_uuid=$(xe_min vm-list is-control-domain=true resident-on=$INSTALLATION_UUID)
    vbd_uuid=$(xe vbd-create device=autodetect type=Disk \
                             vdi-uuid="$data_vdi_uuid" vm-uuid="$dom0_uuid")
    xe vbd-plug uuid=$vbd_uuid
    dev=$(xe_min vbd-list params=device uuid=$vbd_uuid)
    mke2fs -q -j -m0 /dev/$dev
    e2label /dev/$dev vpxstate
    xe vbd-unplug uuid=$vbd_uuid
    xe vbd-destroy uuid=$vbd_uuid
  else
    echo -n "Attaching old data disk... "
  fi
  vbd_uuid=$(xe vbd-create device=2 type=Disk \
                           vdi-uuid="$data_vdi_uuid" vm-uuid="$v")
  xe vbd-param-set other-config:os-vpx-data=true uuid=$vbd_uuid
  echo "done."
}


set_kernel_params()
{
  local v="$1"
  local args=$KERNEL_PARAMS
  local cmdline=$(cat /proc/cmdline)
  for word in $cmdline
  do
    if echo "$word" | grep -q "geppetto"
    then
      args="$word $args"
    fi
  done
  if [ "$args" != "" ]
  then
    echo "Passing Geppetto args to VPX: $args."
    xe vm-param-set PV-args="$args" uuid="$v"
  fi
}


set_other_configs()
{
  local v="$1"
  if [ "$OTHER_CONFIGS" != "" ]
  then
    for conf in $OTHER_CONFIGS
    do
      echo "Setting other-config: $conf."
      xe vm-param-set "other-config:$conf" uuid="$v"
    done
  fi
}


set_memory()
{
  local v="$1"
  if [ "$RAM" != "" ]
  then
    echo "Setting RAM to $RAM MiB."
    [ "$BALLOONING" == 1 ] && RAM_MIN=$(($RAM / 2)) || RAM_MIN=$RAM
    xe vm-memory-limits-set static-min=16MiB static-max=${RAM}MiB \
                            dynamic-min=${RAM_MIN}MiB dynamic-max=${RAM}MiB \
                            uuid="$v"
  fi
}


# Make the VM auto-start on server boot.
set_auto_start()
{
  local v="$1"
  xe vm-param-set uuid="$v" other-config:auto_poweron=true
}


set_all()
{
  local v="$1"
  set_kernel_params "$v"
  set_memory "$v"
  set_auto_start "$v"
  label_system_disk "$v"
  create_gi_vif "$v"
  create_management_vif "$v"
  create_public_vif "$v"
  create_data_disk "$v"
}


log_vifs()
{
  local v="$1"

  (IFS=,
   for vif in $(xe_min vif-list vm-uuid="$v")
   do
    dev=$(xe_min vif-list uuid="$vif" params=device)
    mac=$(xe_min vif-list uuid="$vif" params=MAC | sed -e 's/:/-/g')
    echo "eth$dev has MAC $mac."
   done
   unset IFS) | sort
}


destroy_vifs()
{
  local v="$1"
  IFS=,
  for vif in $(xe_min vif-list vm-uuid="$v")
  do
    xe vif-destroy uuid="$vif"
  done
  unset IFS
}


destroy_data_disk()
{
  local v="$1"
  vdi_uuid=$(xe_min vbd-list vm-uuid="$v" userdevice=2 params=vdi-uuid)
  xe vdi-destroy uuid="$vdi_uuid"
}


get_params "$@"

thisdir=$(dirname "$0")

if [ "$FROM_TEMPLATE" ]
then
  template_uuid=$(find_template "$TEMPLATE_LABEL")
  name=$(xe_min template-list params=name-label uuid="$template_uuid")
  echo -n "Cloning $name... "
  vm_uuid=$(xe vm-clone vm="$template_uuid" new-name-label="$name")
  xe vm-param-set is-a-template=false uuid="$vm_uuid"
  echo $vm_uuid.

  destroy_vifs "$vm_uuid"
  destroy_data_disk "$vm_uuid"
  set_all "$vm_uuid"
  set_other_configs "$vm_uuid"
else
  if [ ! -f "$VPX_FILE" ]
  then
      # Search $thisdir/$VPX_FILE too.  In particular, this is used when
      # installing the VPX from the supp-pack, because we want to be able to
      # invoke this script from the RPM and the firstboot script.
      if [ -f "$thisdir/$VPX_FILE" ]
      then
          VPX_FILE="$thisdir/$VPX_FILE"
      else
          echo "$VPX_FILE does not exist." >&2
          exit 1
      fi
  fi

  echo "Found OS-VPX File: $VPX_FILE. "

  dest_sr=$(get_dest_sr)

  echo -n "Installing $NAME... "
  vm_uuid=$(xe vm-import filename=$VPX_FILE sr-uuid="$dest_sr")
  echo $vm_uuid.

  renumber_system_disk "$vm_uuid"

  nl=$(xe_min vm-list params=name-label uuid=$vm_uuid)
  xe vm-param-set \
    "name-label=${nl/ import/}" \
    other-config:os-vpx=true \
    uuid=$vm_uuid

  set_all "$vm_uuid"

  if [ "$AS_TEMPLATE" ]
  then
    if [ "$TEMPLATE_LABEL" ]
    then
     xe vm-param-set uuid="$vm_uuid" is-a-template=true \
                                     name-label="$TEMPLATE_LABEL" \
                                     other-config:instant=true
    else
     xe vm-param-set uuid="$vm_uuid" is-a-template=true \
                                     other-config:instant=true
    fi
    template_uuid="$vm_uuid"
    echo -n "Installing VPX from template... "
    vm_uuid=$(xe vm-clone vm="$vm_uuid" new-name-label="${nl/ import/}")
    xe vm-param-set is-a-template=false uuid="$vm_uuid"
    echo "$vm_uuid."
    clear_data_config "$template_uuid"
  fi
  set_other_configs "$vm_uuid"
fi

log_vifs "$vm_uuid"

echo -n "Starting VM... "
xe vm-start uuid=$vm_uuid
echo "done."

if [ "$WAIT_FOR_NETWORK" ]
then
  echo "Waiting for network configuration... "
  i=0
  while [ $i -lt 600 ]
  do
    ip=$(xe_min vm-list params=networks uuid=$vm_uuid)
    if [ "$ip" != "<not in database>" ]
    then
      show_ip "$ip" "1" "$BRIDGE_M"
      if [[ $BRIDGE_P ]]
      then
        show_ip "$ip" "2" "$BRIDGE_P"
      fi
      echo "Installation complete."
      exit 0
    fi
    sleep 10
    let i=i+1
  done
fi
