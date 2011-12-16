#!/bin/sh

# @Author: Ewan
# @Comments/submission: Vijay
# Notes: This script creates an SR of type 'iso' on XenServer
# by assuming that the "Local Storage SR" is of type ext. It is
# important to ensure that during installation of XS, the Local
# Storage SR is specified to be a file system SR of type ext
# instead of being created as a volume group (LVHD) by default.
# We will need to run this script immediately after installing XS,
# and before we proceed with any Openstack related configuration.
# Having an SR of type iso and name 'Local ISO SR' will allow
# Donal's code to kick in, where nova-compute searches XS
# for an SR by the name 'local-sorage-iso' (see the i18n-key value
# below), and then provisions VHDs out of Logical Volumes on this SR.
# The actual creation of the logical volumes and VHDs is hidden by
# the XAPI backend. We already have functionality to rip /dev/cdrom
# contents to glance. Having this SR will allow nova-compute to boot
# up instances by copying over the uploaded ISO image to the compute
# node onto this SR and then boot up the VM to allow installation
# using the ISO image.

local_sr=$(xe sr-list --minimal other-config:i18n-key=local-storage)
host=$(xe host-list --minimal)

mkdir /var/run/sr-mount/$local_sr/isos

new_sr=$(xe sr-create host-uuid=$host \
                      name-label='Local ISO SR' \
                      type=iso \
                      content-type=iso \
                      device-config:legacy_mode=true \
                      device-config:location=/var/run/sr-mount/$local_sr/isos)

xe sr-param-set uuid=$new_sr other-config:i18n-key=local-storage-iso
echo $new_sr
