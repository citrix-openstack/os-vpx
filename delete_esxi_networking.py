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
from deploy_vpx.vmwareapi.error_util import FAULT_NOT_FOUND
from deploy_vpx.vmwareapi.error_util import PLATFORM_CONFIG_FAULT


def define_cmd_line_args(parser):
    parser.add_argument('-H', '--host', required=True, nargs=1, type=str,
             help='Host IP or hostname')
    parser.add_argument('-P', '--password', required=True, nargs=1, type=str,
             help='password of root user on host')
    parser.add_argument('-p', '--publicnet', nargs=1, default='vSwitch0', type=str,
             help='name of vSwitch or xenbr/xapi/hyperV interface for public network')
    parser.add_argument('-m', '--mgmtnet', nargs=1, default='OlympusManagementvSwitch', type=str,
             help='name of vSwitch or xenbr/xapi/hyperV interface for private '
             'Geppetto management network')
    parser.add_argument('-t', '--tenantpgrp', nargs=1, default='xenbr0', type=str,
             help='name of tenant port group to be created and associated with '
             'publicnet')


def get_cmd_line_args(parser):
    args = parser.parse_args() 
    return args 


def delete_vm_port_group(session, hns_ref, port_grp_name):
    """ Deletes a specified port group """
    try:
        deploy_util.delete_vm_port_group(session, hns_ref, port_grp_name)
    except Exception as ex:
        print type(ex)
        print ex
        print ex.args
        print ex.fault_list
        if FAULT_NOT_FOUND in ex.fault_list:
            print "Specified object already non-existent"
        if PLATFORM_CONFIG_FAULT in ex.fault_list:
            print "PlatformConfigException encountered"
            sys.exit(1)


def delete_vswitch(session, hns_ref, vswitch_name):
    """ Creates a vSwitch with the specified parameters on the ESX host """
    try:
        deploy_util.delete_vswitch(session, hns_ref, vswitch_name)
    except Exception as ex:
        print "Caught exception!"
        print type(ex)
        print ex
        print ex.args
        if FAULT_NOT_FOUND in ex.fault_list:
            print "Specified object already non-existent"
        if PLATFORM_CONFIG_FAULT in ex.fault_list:
            print "PlatformConfigException encountered"
            sys.exit(1)


if __name__ == '__main__':
    # Create an argparse object.
    parser = argparse.ArgumentParser(description='ESX VPX network setup dismantle script',
             epilog='Please log all bugs at openstack@citrix.com')

    # Define the command line args this script takes by adding the options
    # to the argparse object.
    define_cmd_line_args(parser)
    # Read in command line arguments.
    args = get_cmd_line_args(parser)

    # If check_args() returns success, proceed.
    host_ip = args.host[0]
    host_password = args.password[0]
    mgmt_vswitch_name = args.mgmtnet
    public_vswitch_name = args.publicnet
    tenant_port_grp_name = args.tenantpgrp

    # Set the name of the vSwitch that will host the Olympus Host network.
    # This network is between the VPX and the ESXi host and allows the VPX
    # to make calls to the hypervisor.
    host_vswitch_name = "OlympusHostvSwitch"

    try:
        session = deploy_vpx.login(host_ip, host_password)
        client_factory = session._get_vim().client.factory
        hns_ref = deploy_util.get_networkSystem_ref(session)

        # 'xenbr0' port group is just a network to start with for default Olympus deployments.
        # nova-compute would handle tenant specific networks.
        print "Deleting Olympus tenant port group..."
        print tenant_port_grp_name

        delete_vm_port_group(session, hns_ref, tenant_port_grp_name)

        # Next, we delete a vSwitch by name host_vswitch_name to host the Olympus Host Network,
        # which is the network used by VPX to communicate with the underlying ESX host.
        # But first, delete the port groups in the vswitch
        print "Deleting Olympus Host Network port group.."
        host_port_grp_name = 'Olympus Host Network'
        delete_vm_port_group(session, hns_ref, host_port_grp_name)
        # Before we attempt to delete the vmkernel port group, we need to first delete the
        # vnic associated with it. Each vnic in a port group has a name associated with it.
        # This name is returned to us when we create the vnic using
        # deploy_util.create_vm_kernel_port().
        # So we retrieve a list of the vnics (vm kernel ports) associated with this port
        # group.
        host_vswitch_port_grp_name = 'Olympus Host VMKernel'
        ohvmk_list = deploy_util.get_vmkernel_device_list_given_port_group_name(session, host_vswitch_port_grp_name)
        #print ohvmk_list
        # We know that we configure only one VMKernel port in this above port group.
        # So we just pick the first element in the above list.
        if ohvmk_list:
            ohvmkernel_port = ohvmk_list[0];
            dev_name = ohvmkernel_port.device
            print "dev_name is ---> " + dev_name
            # Delete this vnic.
            try:
                deploy_util.delete_vm_kernel_port(session, hns_ref, dev_name)
            except Exception, ex:
                print ex.args
                if FAULT_NOT_FOUND in ex.fault_list:
                    print "Specified object already non-existent"
                    pass

        # Then, delete the port group that contained the vnic.	
        print "Deleting Olympus Host VMKernel port group.."
        delete_vm_port_group(session, hns_ref, host_vswitch_port_grp_name)
        # Finally the host communication vSwitch
        print "Deleting Olympus Host vSwitch.."
        delete_vswitch(session, hns_ref, host_vswitch_name)

        # As the last step, delete the management vSwitch that hosts the Olympus Management Network that is used
        # by VPXs to communicate with each other.
        # First delete the port group in it.
        print "Deleting the Olympus management Network port group.."
        mgmt_vswitch_port_grp_name = 'Olympus Management Network'
        delete_vm_port_group(session, hns_ref, mgmt_vswitch_port_grp_name)
        print "Deleting the Olympus management vswitch.."
        print "Deleting mgmt vSwitch ", mgmt_vswitch_name
        delete_vswitch(session, hns_ref, mgmt_vswitch_name)

    except Exception, ex:
        print("Exception : %s") % ex
