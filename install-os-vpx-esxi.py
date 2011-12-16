# vim: tabstop=4 shiftwidth=4 softtabstop=4

# Copyright (c) 2011 Citrix Systems, Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.


import sys
import argparse

import deploy_vpx
from deploy_vpx import deploy_util
from deploy_vpx import util
from deploy_vpx.flags import FLAGS
from deploy_vpx.vmwareapi import vim_util

def define_cmd_line_args(parser):
    parser.add_argument('-H', '--host', required=True, nargs=1, type=str,
            help='Host IP or hostname')
    parser.add_argument('-P', '--password', required=True, nargs=1, type=str,
            help='password of root user on host')
    parser.add_argument('-f', '--filepath', nargs=1, required=True, type=str,
            help='absolute pathname of VPX\'s ovf file')
    parser.add_argument('-M', '--geppetto_master', nargs=1, default='false', type=str,
            help='Kernel parameter specifying whether VPX should be made master [true|false]')
    parser.add_argument('-N', '--geppetto_default_networking', nargs=1, default='false', type=str,
            help='Kernel parameter specifying whether VPX should accept default [true|false]'
            'network settings')


def get_cmd_line_args(parser):
    args = parser.parse_args()
    return args


if __name__ == '__main__':
    """ Main function of install-os-vpx-esxi.py """
    # Create an argparse object.
    parser = argparse.ArgumentParser(description='ESX VPX create script',
                 epilog='Please log all bugs at openstack@citrix.com')

    # Define the command line args this script takes by adding the options
    # to the argparse object.
    define_cmd_line_args(parser)
    # Read in command line arguments.
    args = get_cmd_line_args(parser)

    # If check_args() returns success, proceed.
    host_ip = args.host[0]
    host_password = args.password[0]
    ovf_template = args.filepath[0]
    # The params below are not required so they have default values.
    if (args.geppetto_master != 'false'):
        master_flag = args.geppetto_master[0]
    else:
        master_flag = args.geppetto_master

    if (args.geppetto_default_networking != 'false'):
        def_net_flag = args.geppetto_default_networking[0]
    else:
        def_net_flag = args.geppetto_default_networking

    kernel_params = []
    if master_flag == 'true':
        kernel_params += ["geppetto_master=true"]
    if def_net_flag == 'true':
        kernel_params += ["geppetto_default_networking=true"]

    print "kernel_params =", kernel_params

    # The IP of the ESX host (Console OS) is fixed to 192.168.128.1.
    # This will be the ip of the vmkernel port that is created in
    # vSwitch1 on the ESX host. The VPX will talk to the ESX COS
    # by connect()ing to this ip. 
    host_vmkport_ip = "192.168.128.1"

    session = deploy_vpx.login(host_ip, host_password)
    vm_name = util.get_unique_vm_name()
    #TODO: Check the uniqueness of the VM
    try:
        servicecontent = session._get_vim().get_service_content()
        client_factory = session._get_vim().client.factory
        vim_obj = session._get_vim()
        network_names = [FLAGS.HOST_NETWORK_NAME, FLAGS.MANAGEMENT_NETWORK_NAME]

        dc_mor, dc_name = deploy_util.get_dc_info(session)
        ds_mor, ds_name = deploy_util.get_ds_info(session)
        host_mor, host_name = deploy_util.get_host_info(session)
        networks = deploy_util.get_network_info(session, network_names)
        vm_folder_mor = deploy_util.get_vmfolder_info(session)
        rp_mor = deploy_util.get_resourcepool_info(session)

        import_config_params = deploy_util.create_import_configspec_params(\
                                client_factory, host_mor, networks, vm_name)
        ovf_file = open(ovf_template, "r")
        ovf_desc = ovf_file.read()
        ovf_file.close()
        ovf_import_result = deploy_util.get_import_result(session,
                                        servicecontent.ovfManager,
                                        ovf_desc, rp_mor, ds_mor,
                                        import_config_params)
        print ovf_import_result
        #total_size = get_upload_file_size()
        http_lease = deploy_util.get_httplease(session, rp_mor,
                                           ovf_import_result.importSpec,
                                           vm_folder_mor, host_mor)
        lease_state = deploy_util.wait_for_lease(session, http_lease)
        http_lease_info = deploy_util.get_httplease_info(session, http_lease)
        if lease_state == 'ready':
            deploy_util.print_httplease_info(http_lease_info, host_ip)
            cookies = deploy_util.get_cookies(session)
            path_prefix = util.get_path_prefix(ovf_template)
            deploy_util.upload_vm_files(host_ip, http_lease_info,
					ovf_import_result,
					cookies, path_prefix)
            deploy_util.set_httplease_status(session, http_lease)
            print "Import completed."

        # We will assign a static IP to eth0 of the VPX VM we are creating
        # by injecting a custom guestinfo.guestip parameter into the VPX's
        # VMX file. We also inject this same static IP to another property
        # called "annotation". The reason for us to do this is that
        # guestinfo.* values do not persist across host reboots, or if all
        # outstanding connections to that ESX host are dropped, the
        # guestinfo.* values are erased. guestinfo.* values can be queried
        # using vmtoolsd --cmd='info.get guestinfo.<property_name>'.
        # Presently, I am not aware of a CLI to retrieve the annotation
        # property from within the guest VPX VM.

        # We first query for the list of annotation values via the SOAP vi SDK
        # on all existing VMs on the host.
        # We then pick an ip value in the range 192.168.128.2 to
        # 192.168.128.254 that is not already present in the retrieved
        # annotation (guestip) list and assign it to the new VM's guestip.
        # When the VM starts up, and we call set_config_params() below, it
        # calls the SOAP vi SDK API function ReconfigVM_Task which does the
        # injection. Next, we have also packaged an init.d script citrix-esx-geppetto-network
        # in the VPX's /etc/init.d/ in run levels 2,3,4,5 (see the chkconfig line
        # of this file). We also will run chkconfig --add on this file as part of
        # build-vpx-overlay.sh. This file will thus be placed in both the vmdk and
        # the xva (ESX and XS respectively), but since we check for vmtoolsd in
        # the script, it will run only on ESX. When the VPX boots up, init will invoke 
        # this script, and will create a soft link S09-citrix-geppetto-network (again this
        # 09 comes from the chkconfig line in the script), and will execute the script.
        # The script creates the eth0 interface after querying for the guestinfo.guestip
        # value using vmtoolsd, (if there is a CLI to pick up the annotation value, we can
        # just use that and do away with guestinfo.guestip) and creating the ifcfg-eth0 file.
        # The S10network script (a standard script) will then actually bring up this
        # interface alongwith all other configured interfaces. 

        # First, build guestip list.
        guest_ip_list = deploy_util.get_annotation_values_across_vms(session)
        print "Printing list of ip addresses allocated to VPX VMs on host " + host_ip
        print guest_ip_list

        # Next, find an unused ip.
        guest_ip=""
        for i in range(2, 254, 1):
            ip = "192.168.128." + str(i)
            if ip not in guest_ip_list:
                guest_ip = ip
                break

        print "guestinfo.guestip is --> " + guest_ip

        if guest_ip == "":
            print "Could not allocate an IP for VM communication with host. Exiting with failure."
            exit(1)

        vm_uuid = deploy_util.get_vm_uuid_from_name(session, vm_name)
        if not vm_uuid:
            print("Unable to find a VM with name %s", vm_name)

        print "Allocating IP " + guest_ip + " to VM"
        params = {'guestinfo.uuid': vm_uuid,
                'guestinfo.hypervisor.hostIP': host_vmkport_ip,
                'machine.id': 'os-vpx',
                'guestinfo.guestip': guest_ip}
        if kernel_params:
            params['guestinfo.master'] = ' '.join(kernel_params)

        vm_ref = deploy_util.get_vm_ref_from_the_name(session, vm_name)
        #set custom property of vm to 'os-vpx'
        #this property will be looked for to uninstall the geppetto cloud.

        print("Starting %s") % vm_name
        start_task = deploy_util.vm_start(session, vm_ref)
        if deploy_util.wait_for_task(session, start_task) == False:
            raise Exception(("Attempt to start VM %s failed.") % vm_name)
        print "Injecting guest information into the VPX."
        # We send the guest_ip as a separate parameter and not in params since it is a
        # simple string. Refer to the wsdl description of VirtualMachineConfigSpec.
        deploy_util.set_config_params(session, client_factory, vm_ref, params, guest_ip)

        print "Successfully passed guest information to vmtools in VPX."

        #TODO: Attach state disk

    except Exception, e:
	print("Exception: %s") % e

