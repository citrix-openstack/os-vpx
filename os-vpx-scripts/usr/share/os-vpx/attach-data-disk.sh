#!/bin/sh

set -eux

. /etc/openstack/hapi

declare -a on_exit_hooks
declare -a reason_args
declare -i reason_code=0 # No Error
                         # 1 - VDI already in use
                         # 2 - Ambiguous VDIs
                         # 3 - Unable to create disk
                         # 4 - Failed mount

on_exit()
{
    for i in "${on_exit_hooks[@]}"
    do
        eval $i
    done
}

add_on_exit()
{
    local n=${#on_exit_hooks[*]}
    on_exit_hooks[$n]="$*"
    if [[ $n -eq 0 ]]
    then
        trap on_exit EXIT
    fi
}

handle_reason()
{
    case $reason_code in
         4)
            # mount failure, try to re-format and re-mount
            if [[ $? -eq 32 ]]
            then
                 fs="${reason_args[0]}"
                 dv="${reason_args[1]}"
                 mp="${reason_args[2]}"
                 make_fs "$fs" "$dv"
                 mount "$mp"
            fi
            ;;
         *)
            echo Reason code: $reason_code
            ;;
    esac
}

add_on_exit "handle_reason || true"

add_fstab_entry()
{
  local dev="$1"
  local mp="$2"
  local rest="$3"
  grep -v "$mp" /etc/fstab >/etc/fstab.tmp
  echo "$dev $mp $rest" >>/etc/fstab.tmp
  mv /etc/fstab.tmp /etc/fstab
}

del_fstab_entry()
{
  local mp="$1"
  grep -v "$mp" /etc/fstab >/etc/fstab.tmp
  mv /etc/fstab.tmp /etc/fstab
}

make_fs()
{
   local fs="$1"
   local dev="$2"
   if [ "$fs" = "xfs" ]
   then
       /sbin/mkfs.xfs -i size=1024 "/dev/$dev"
   elif [ "$fs" != "nofs" ]
   then
      /sbin/mke2fs -q -j -m0 "/dev/$dev"
   fi
}

attach_data_disk()
{
  local dev="$1"
  local mp="$2"
  local name="$3"
  local key="$4"
  local fs="$5"
  local ug="$6"
  local virtual_size="$7"

 if mount | grep -q "$mp"
  then
    echo "$mp already mounted; nothing to do." >&2
  else
    if [ -b "/dev/$dev" ]
    then
      n="1"
    else
      vdi=$(os-vpx-find-vdi "$key")

      n=$(echo "$vdi" | wc -w)
      if [ "$n" = "0" ]
      then
        vdi=$(os-vpx-create-vdi "$name" $(( $virtual_size << 30 )) "$key")
      elif [ "$n" = "1" ]
      then
        in_use=$(os-vpx-vdi-in-use "$vdi")
        if [ "$in_use" = "yes" ]
        then
          echo "VDI already in use.  Bailing!" >&2
          reason_code=1
          exit 1
        fi
      else
        echo "Ambiguous VDIs with key $key.  Bailing!" >&2
        reason_code=2
        exit 1
      fi

      if [ "$vdi" != "None" ]
      then
        os-vpx-attach-vdi "$vdi" "$dev"
      else
        echo "Unable to create disk, please check that there is sufficient space available."
        reason_code=3
        exit 1
      fi

      if [ "$n" = "0" ]
      then
        make_fs "$fs" "$dev"
      fi
    fi # $dev ! -b

    if [ "$fs" = "xfs" ]
    then
      add_fstab_entry "/dev/$dev" "$mp" \
                      "xfs noatime,nodiratime,nobarrier,logbufs=8 0 0"
    else
      add_fstab_entry "/dev/$dev" "$mp" "ext3 defaults 1 2"
    fi

    if [ "$mp" != "nomp" ]
    then
      mkdir -p "$mp"
      reason_code=4
      reason_args=( "$fs" "$dev" "$mp" )
      mount "$mp"
      if [ "$n" = "0" ]
      then
        chown "$ug" "$mp"
      fi
    fi
  fi # ! mount
}
