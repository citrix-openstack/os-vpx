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
    parser.add_argument('-e', '--pnic', nargs=1, type=str,
             help='name of the physical NIC mgmtnet should be associated with')
    parser.add_argument('-n', '--numports', nargs=1, default='60', type=int,
             help='number of ports in the management vSwitch to be created')
    parser.add_argument('-t', '--tenantpgrp', nargs=1, default='xenbr0', type=str,
             help='name of tenant port group to be created and associated with '
             'publicnet')

 
def get_cmd_line_args(parser):
    args = parser.parse_args() 
    return args 


def add_vswitch(client_factory, hns_ref, vswitch_name, num_ports, bridge=None,
                policy=None):
    """ Creates a vSwitch with the specified parameters on the ESX host """
    print "Adding vswitch " + vswitch_name
    try:
        deploy_util.add_vswitch(session, client_factory, hns_ref, vswitch_name,
                                num_ports, bridge, policy)
    except Exception as ex:
        print "Caught exception!"
        print type(ex)
        print ex
        print ex.args
        print ex.fault_list
        if PLATFORM_CONFIG_FAULT in ex.fault_list:
            print "Encountered PlatformConfigFault Exception"
            sys.exit(1)


if __name__ == '__main__':
    # Create an argparse object.
    parser = argparse.ArgumentParser(description='ESX network setup script',
             epilog='Please log all bugs at openstack@citrix.com')

    # Define the command line args this script takes by adding the options
    # to the argparse object.
    define_cmd_line_args(parser)
    # Read in command line arguments.
    args = get_cmd_line_args(parser)

    # If check_args() returns success, proceed.
    host_ip = args.host[0]
    host_password = args.password[0]
    vswitch_size_in_ports = args.numports
    # Assign values for those fields that don't have default values.
    if (args.pnic):
        mgmt_host_adapter = args.pnic[0]
    else:
        mgmt_host_adapter = args.pnic

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

        # First, we create a vSwitch by name host_vswitch_name to host the Olympus Host Network,
        # which is the network used by VPX to communicate with the underlying ESX host.
        add_vswitch(client_factory, hns_ref, host_vswitch_name, vswitch_size_in_ports)

        # Next, we add a port group to this vswitch we just created. We once again use the
        # hns reference, supplying it the vswitch name.
        # Refer to http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.NetworkSystem.html
        # for a list of all the functions that we can invoke on the HostNetworkSystem object.
        port_grp_name = "Olympus Host Network"
        deploy_util.create_vm_port_group(session, client_factory, hns_ref, host_vswitch_name, port_grp_name)

        # Create another port group by name "VMKernel" in this OlympusHostvSwitch.
        port_grp_name = "Olympus Host VMKernel"
        deploy_util.create_vm_port_group(session, client_factory, hns_ref, host_vswitch_name, port_grp_name)
        # Next, add a vm kernel port to the port group "VMKernel".
        # We plumb ip 192.168.128.1 to this vmkernel port.
        vmkernel_port_ip = "192.168.128.1"
        vmkernel_port_netmask = "255.255.255.0"
        dhcp_flag = False
        vmkernel_port_mac = None
        virt_console_nic_dev = deploy_util.create_vm_kernel_port(session, client_factory, \
                                    hns_ref, host_vswitch_name, port_grp_name, \
                                    vmkernel_port_ip, vmkernel_port_netmask, \
                                    dhcp_flag, vmkernel_port_mac)

        print "Created and attached vmkernel port " + virt_console_nic_dev + " to Olympus Host VMKernel Port Group"
 
        print "Creating tenant networks..."
        # 'xenbr0' port group is just a network to start with for default Olympus deployments.
        # nova-compute would handle tenant specific networks.
        deploy_util.create_vm_port_group(session, client_factory, hns_ref, public_vswitch_name, tenant_port_grp_name)


        # Add vSwitch that hosts the Olympus Management Network that is used by VPXs to
        # communicate with each other.
        print "Adding vSwitch ", mgmt_vswitch_name
        # If the pnic is specified, associate it with the management vSwitch.
        if (mgmt_host_adapter):
            bridge = deploy_util.create_vswitch_bridge_spec(client_factory, mgmt_host_adapter)
            add_vswitch(client_factory, hns_ref, mgmt_vswitch_name, vswitch_size_in_ports, bridge)
        else:
            add_vswitch(client_factory, hns_ref, mgmt_vswitch_name, vswitch_size_in_ports)

        # Create the "Olympus Management Network" port group on the OlympusManagementvSwitch.
        port_grp_name = "Olympus Management Network"
        print "Creating port group ", port_grp_name
        deploy_util.create_vm_port_group(session, client_factory, hns_ref, mgmt_vswitch_name, port_grp_name)

    except Exception, ex:
        print("Exception : %s") % ex
        print ex.fault_list
