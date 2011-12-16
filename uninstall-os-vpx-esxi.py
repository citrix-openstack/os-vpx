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

import deploy_vpx
from deploy_vpx import deploy_util


def uninstall_geppetto_cloud(session, os_vpx_key='os-vpx'):
    """Cleanup Geppetto cloud deployed on ESXi host(s)."""
    # Cleanup all VMs
    try:
        os_vpx_vms = deploy_util.get_vms_with_property(session, os_vpx_key)
        if len(os_vpx_vms) == 0:
            print("Found no VM with custom property label : %s") % os_vpx_key
        for vm in os_vpx_vms:
            deploy_util.destroy_vm(session, vm)
            print("Deleted VM %s") % vm[1]
        return True

    except Exception, ex:
        print("Exception : %s") % ex
        return False


if __name__ == '__main__':
    if len(sys.argv) == 3:
        host_ip = sys.argv[1]
        host_password = sys.argv[2]
    else:
        print('Usage: \n\t %s <Host> <Host (root) Password>\n') % sys.argv[0]
        exit(1)

    try:
        session = deploy_vpx.login(host_ip, host_password)
        if uninstall_geppetto_cloud(session) == True:
            print("\nSuccessfully cleaned up Geppetto Cloud VMs and "
                  "data host %s.\n") % host_ip
    except Exception, ex:
        print("Exception : %s") % ex
