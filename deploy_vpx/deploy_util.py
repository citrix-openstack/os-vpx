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


import httplib
import os
import time
import urlparse

from deploy_vpx.flags import FLAGS
from deploy_vpx.vmwareapi import vim_util


def get_vm_ref_from_the_name(session, vm_name):
    """Get reference to the VM with the name specified."""
    vms = session._call_method(vim_util, "get_objects",
                "VirtualMachine", ["name"])

    for vm in vms:
        if vm.propSet[0].val == vm_name:
            return vm.obj
    return None


def get_vm_uuid_from_name(session, vm_name):
    """Get uuid of the VM with specified name."""
    vms = session._call_method(vim_util, "get_objects",
                   "VirtualMachine", ["name"])
    for vm in vms:
        if vm.propSet[0].val == vm_name:
            return session._call_method(vim_util, "get_dynamic_property",
                                    vm.obj, "VirtualMachine", "config.uuid")
    return None


def vm_start(session, vm_ref):
    return session._call_method(session._get_vim(), "PowerOnVM_Task", vm_ref)


def build_virtual_disk_search_spec(client_factory):
    """Builds HostDatastoreBrowserSearchSpec to search all the virtual disks
    in specified datastore."""
    browser_search_spec = \
        client_factory.create('ns0:HostDatastoreBrowserSearchSpec')
    browser_search_spec.matchPattern = ["*.vmdk"]
    return browser_search_spec


def create_import_configspec_params(client_factory, host_mor, networks,
                                    new_vm_name="os-vpx"):
    ovf_spec_params = client_factory.create('ns0:OvfCreateImportSpecParams')
    ovf_spec_params.locale = "US"
    ovf_spec_params.deploymentOption = ""
    ovf_spec_params.entityName = new_vm_name
    ovf_spec_params.hostSystem = host_mor
    ovf_spec_params.propertyMapping = []
    network_mapping_spec = []
    for network in networks:
        network_spec = client_factory.create('ns0:OvfNetworkMapping')
        network_spec.network = network['mor']
        network_spec.name = network['name']
        network_mapping_spec.append(network_spec)
    ovf_spec_params.networkMapping = network_mapping_spec
    return ovf_spec_params


def print_httplease_info(http_lease_info, host):
    print "HttpNfcLeaseInfo : "
    print "leaseTimeout = ", http_lease_info.leaseTimeout
    print "totalDiskCapacityInKB = ", http_lease_info.totalDiskCapacityInKB
    for durl in http_lease_info.deviceUrl:
        print "deviceUrl.key = ", durl.key
        print "deviceUrl.importKey = ", durl.importKey
        print "deviceUrl.url = ", durl.url
        print "updated device url = ", durl.url.replace("*", host)


def print_ovffile_info(file_item):
    print "create: ", file_item.create
    print "deviceId: ", file_item.deviceId
    print "path: ", file_item.path
    print "size: ", file_item.size


def upload_vmdk_file(if_create, local_file, url, size,
                     host_ip, cookies, chunk_size=FLAGS.CHUNK_SIZE):
    """Upload specified local_file to specified url in chunks.
    The parameter if_create is set then create new file on ESXi server."""
    try:
        (scheme, netloc, path, params, query, frag) = urlparse.urlparse(url)
        conn = httplib.HTTPSConnection(netloc)
        if params:
            path = path + "?" + params
        if if_create:
            conn.putrequest("PUT", path)
        else:
            conn.putrequest("POST", path)
        conn.putheader("User-Agent", FLAGS.USER_AGENT)
        conn.putheader("Content-Length", size)
        conn.putheader("Cookie", cookies)
        conn.endheaders()

        fp = open(local_file, "rb")
        while True:
            data = fp.read(chunk_size)
            if not data:
                break
            conn.send(data)

        fp.close()
        conn.close()

    except Exception, e:
        print("Exception during vmdk file upload to host %s. "
              "\nException: %s") % (host_ip, e)
        if fp:
            fp.close()
        if conn:
            conn.close()
        exit(1)


def get_vmconfig_change_spec(client_factory, params, annotation):
    """Builds the config spec to set virtual machine name in vmx file."""
    virtual_machine_config_spec = \
        client_factory.create('ns0:VirtualMachineConfigSpec')

    opts = []
    for key in params:
        opt = client_factory.create('ns0:OptionValue')
        opt.key = key
        opt.value = params[key]
        opts.append(opt)

    #print "options :", opts
    virtual_machine_config_spec.extraConfig = opts
    virtual_machine_config_spec.annotation = annotation
    return virtual_machine_config_spec


def set_config_params(session, client_factory, vm_mor, params, annotation):
    """Set the virtual machine name and host ip in vmx file for
    the guest tools to pickup."""
    reconfigure_spec = \
            get_vmconfig_change_spec(client_factory, params, annotation)
    reconfig_task = session._call_method(session._get_vim(),
                           "ReconfigVM_Task", vm_mor,
                           spec=reconfigure_spec)
    return wait_for_task(session, reconfig_task)


def get_dc_info(session):
    dc_obj = session._call_method(vim_util, "get_objects",
                                  "Datacenter", ["name"])
    return dc_obj[0].obj, dc_obj[0].propSet[0].val


def get_ds_info(session):
    data_stores = session._call_method(vim_util, "get_objects",
                    "Datastore",
                    ["summary.type", "summary.name", "summary.datastore"])
    for ds in data_stores:
        ds_name = None
        ds_type = None
        for prop in ds.propSet:
            if prop.name == "summary.type":
                ds_type = prop.val
            elif prop.name == "summary.name":
                ds_name = prop.val
            elif prop.name == "summary.datastore":
                ds_mor = prop.val
        if ds_type == "VMFS":
            return ds_mor, ds_name


def get_host_info(session):
    host_obj = session._call_method(vim_util, "get_objects",
                                    "HostSystem", ["name"])
    return host_obj[0].obj, host_obj[0].propSet[0].val


def get_network_with_the_name(session, network_name="vmnet0"):
    """
    Gets reference to the network whose name is passed as the
    argument.
    """
    hostsystems = session._call_method(vim_util, "get_objects",
                "HostSystem", ["network"])
    vm_networks_ret = hostsystems[0].propSet[0].val
    # Meaning there are no networks on the host. suds responds with a ""
    # in the parent property field rather than a [] in the
    # ManagedObjectRefernce property field of the parent
    if not vm_networks_ret:
        return None
    vm_networks = vm_networks_ret.ManagedObjectReference
    networks = session._call_method(vim_util,
                "get_properties_for_a_collection_of_objects",
                "Network", vm_networks, ["summary.name"])

    for network in networks:
        if network.propSet[0].val == network_name:
            return network.obj
    return None


def get_network_info(session, network_names):
    """Returns a list of dictionary objects with Managed object reference and
    name corresponding to each network specified.
    networks = [{'mor' : mor_network1, 'name' : network_names[0],
                {'mor' : mor_network2, 'name' : network_names[1]}]
    """
    networks = []
    for network in network_names:
        network_mor = get_network_with_the_name(session, network)
        network_name = network
        networks.append({'mor': network_mor, 'name': network_name})
    return networks


def get_networkSystem_ref(session):

    hs_ref = session._call_method(vim_util, "get_objects",
    		    "HostSystem", ["name"])
    host = hs_ref[0]

    configManager = session._call_method(vim_util, "get_dynamic_property",
                                             host.obj, "HostSystem",
                                             "configManager")
    networkSystem = session._call_method(vim_util, "get_dynamic_property",
                                             host.obj, "HostSystem",
                                             "configManager.networkSystem")
    return networkSystem

def get_port_group_list(session):
    """ Returns a list of port groups configured on this ESX host"""
    #### NOTE:: This function has NOT BEEN TESTED!!
    # First get a reference to the HostNetworkSystem object.
    hns_ref = get_networkSystem_ref(session)
    # Then, return the portgroup list. This is of type HostPortGroupConfig[].
    # See link for details -
    # http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.NetworkConfig.html
    portgroup_arr = session._call_method(vim_util, "get_dynamic_property",
					    hns_ref, "HostNetworkSystem",
					    "portgroup")
    return portgroup_arr


def get_vmkernel_device_list_given_port_group_name(session, port_grp_name):
    hns_ref = get_networkSystem_ref(session)
    vnic_list = session._call_method(vim_util, "get_dynamic_property",
				    hns_ref, "HostNetworkSystem",
				    "networkConfig.vnic")
    #print " ******* vnic_list is ********"
    #print vnic_list
    # Go through this list and pick out those vnics belonging to specified
    # port group.
    answer_list = []
    for vnic in vnic_list[0]:
	#print "############## vnic ############"
	#print vnic
        if (vnic.portgroup == port_grp_name):
            answer_list.append(vnic)

    return answer_list	


def get_vswitch_info(session):
    """ Prints all vSwitches configured on the ESX host. Function needs improvements. """
    # TODO: Change the function body. Checking in this code to not lose track of what
    # we may need to query. This function isn't used currently.
    #answer = session._call_method(vim_util, "get_objects",
    #				    "HostNetworkSystem", ["networkConfig"].name)
    dummy = session._call_method(vim_util, "get_objects",
				    "HostSystem", "summary")
    dummy = session._call_method(vim_util, "get_objects",
				    "HostSystem", "vm")
    dummy = session._call_method(vim_util, "get_objects",
				    "HostSystem", ["network"])
    dummy = session._call_method(vim_util, "get_objects",
				    "HostSystem", "configManager.networkSystem")

    #dummy = session._call_method(vim_util, "get_objects",
    #				    "HostSystem", ["configManager.networkSystem.networkConfig.pnic"])
    dummy = session._call_method(vim_util, "get_dynamic_property",
    				    "HostSystem", "configManager.networkSystem.networkConfig")

    pnic_info = session._call_method(vim_util, "get_dynamic_property",
				    dummy, "HostSystem", ["configManager.networkSystem.networkConfig.pnic"])


def get_vmfolder_info(session):
    """Returns MOR for default VM folder."""
    dc_obj = session._call_method(vim_util, "get_objects",
                                        "Datacenter", ["vmFolder"])
    return dc_obj[0].propSet[0].val


def get_resourcepool_info(session):
    return session._call_method(vim_util, "get_objects", "ResourcePool")[0].obj


def set_empty_config_properties(result):
    result.importSpec.configSpec.deviceChange[3].device.backing.fileName = ""
    return result


def get_cookies(session):
    """Returns cookies of ESXi host."""
    return session._get_vim().client.options.transport.cookiejar


def set_httplease_status(session, http_lease, percent=100):
    """Sets the httpnfslease progress to specified percentage.
    If percentage is 100 then marks the httpnfclease to completion.
    This means import operation is complete."""
    if percent == 100:
        session._call_method(session._get_vim(),
                             "HttpNfcLeaseComplete", http_lease)
    else:
        #session._call_method(session._get_vim(), "HttpNfcLeaseProgress",
        #                     http_lease, percent)
        pass


def upload_vm_files(host_ip, http_lease_info,
                    ovf_import_result, cookies, path_prefix):
    """Upload all the files associated with OVF template to ESXi host to
    complete import operation."""
    for durl in http_lease_info.deviceUrl:
        device_key = durl.importKey
        for file_item in ovf_import_result.fileItem:
            if device_key == file_item.deviceId:
                print "Import key : ", device_key
                abs_file = path_prefix + file_item.path
                upload_url = durl.url.replace("*", host_ip)
                print("Uploading %s to url %s") % (abs_file, upload_url)
                upload_vmdk_file(file_item.create, abs_file, upload_url,
                                 file_item.size, host_ip, cookies)
                print("Upload of %s completed.") % (abs_file)


def get_import_result(session, ovf_manager, ovf_desc, rp_mor, ds_mor,
                      import_config_params):
    ovf_import_result = session._call_method(session._get_vim(),
                                "CreateImportSpec", ovf_manager,
                                ovfDescriptor=ovf_desc, resourcePool=rp_mor,
                                datastore=ds_mor, cisp=import_config_params)
    return set_empty_config_properties(ovf_import_result)


def get_httplease_state(session, http_lease):
    return session._call_method(vim_util, "get_dynamic_property",
                                http_lease, "HttpNfcLease", "state")


def get_httplease_info(session, http_lease):
    return session._call_method(vim_util, "get_dynamic_property",
                                http_lease, "HttpNfcLease", "info")


def get_httplease(session, rp_mor, import_spec, vm_folder_mor, host_mor):
    return session._call_method(session._get_vim(), "ImportVApp", rp_mor,
                                      spec=import_spec,
                                      folder=vm_folder_mor, host=host_mor)


def wait_for_lease(session, http_lease):
    """Busy wait until lease state becomes 'ready' or 'error'"""
    lease_state = get_httplease_state(session, http_lease)
    while lease_state != 'ready' and lease_state != 'error':
        time.sleep(2)
        lease_state = get_httplease_state(session, http_lease)
    if lease_state == 'error':
        raise Exception("HttpNfcLease error")
    elif lease_state == 'ready':
        return lease_state


def get_vm_powerstate(session, vm_ref):
    vm_info = session._call_method(vim_util, "get_objects",
                            "VirtualMachine", "summary.runtime.powerState")
    return vm_info.propSet[0].val


def wait_for_task(session, task):
    state = session._call_method(vim_util, "get_dynamic_property",
                                 task, "Task", "info.state")
    while state != 'success' and state != 'error':
        time.sleep(1)
        state = session._call_method(vim_util, "get_dynamic_property",
                                         task, "Task", "info.state")
    if state == 'success':
        return True
    else:
        task_error = session._call_method(vim_util, "get_dynamic_property",
                                        task, "Task", "info.error")
        print("Task execution failed with error : %s", task_error)
        return False


def get_annotation_values_across_vms(session):
    answer_list = []
    vms = session._call_method(vim_util, "get_objects",
                              "VirtualMachine", ["name"])
    for vm in vms:
	# Retrieve the value of the annotation field of this vm.
	# Refer to the wsdl definition of VirtualMachine.
	# This VirtualMachine.config.annotation field is a simple
	# string, unlike VirtualMachine.config.extraConfig which is
	# basically a list and thus needs to be parsed.
        annotation = session._call_method(vim_util, "get_dynamic_property",
                                             vm.obj, "VirtualMachine",
                                             "config.annotation")

	# Append this annotation value to the answer_list and return the answer_list.
	answer_list.append(annotation)

    return answer_list


def get_key_values_across_vms(session, key):
    answer_list = []
    vms = session._call_method(vim_util, "get_objects",
                              "VirtualMachine", ["name"])
    for vm in vms:
        # Retrieve the extra configurations of this vm.
        extra_options = session._call_method(vim_util, "get_dynamic_property",
                                             vm.obj, "VirtualMachine",
                                             "config.extraConfig")

        # Next, search for the key in this extraconfig set.
        for option in extra_options:
                for custom_property in option[1]:
                        if custom_property['key'] == key:
                                # print custom_property
                                # Append its value to a list.
                                answer_list.append(custom_property['value'])

    return answer_list 


def get_custom_property(session, vm_ref):
    extra_options = session._call_method(vim_util, "get_dynamic_property",
                                          vm_ref, "VirtualMachine",
                                          "config.extraConfig")
    for option in extra_options:
        for custom_property in option[1]:
            if custom_property['key'] == 'machine.id':
                return custom_property['value']


def get_vms_with_property(session, custom_property):
    """Get references to all VMs with summary.customValue set to
    specified custom_value. A sample use case is to enumerate all
    VMs that are part of Citrix Geppetto Cloud."""
    vm_list = []
    vms = session._call_method(vim_util, "get_objects",
                               "VirtualMachine", ["name"])
    for vm in vms:
        if get_custom_property(session, vm.obj) == custom_property:
            vm_list.append((vm.obj, vm.propSet[0]['val']))
    return vm_list


def destroy_vm(session, vm):
    """Destroy a VM instance. Steps followed are:
        1. Power off the VM, if it is in poweredOn state.
        2. Un-register a VM.
        3. Delete the contents of the folder holding the VM related data."""
    vm_ref, vm_name = vm
    if vm_ref is None:
        return
    try:
        vm_properties = ["config.files.vmPathName", "runtime.powerState"]
        props = session._call_method(vim_util, "get_object_properties",
                                     None, vm_ref,
                                     "VirtualMachine", vm_properties)
        vm_pwr_state = None
        vm_path_name = None
        for elem in props:
            for prop in elem.propSet:
                if prop.name == "runtime.powerState":
                    vm_pwr_state = prop.val
                elif prop.name == "config.files.vmPathName":
                    vm_path_name = prop.val

        if vm_path_name:
            datastore_name, vmx_file_path = split_datastore_path(vm_path_name)

        if vm_pwr_state == "poweredOn":
            print("Powering off the VM %s") % vm_name
            poweroff_task = session._call_method(session._get_vim(),
                                                 "PowerOffVM_Task", vm_ref)
            if wait_for_task(session, poweroff_task) == False:
                print("Failed to power off the VM : %s") % vm_name

        # Un-register the VM
        try:
            print("Unregistering the VM %s") % vm_name
            session._call_method(session._get_vim(), "UnregisterVM", vm_ref)
            print("Unregistered the VM %s") % vm_name
        except Exception, excep:
            print("Failed to unregister the VM %s due to exception : %s") % \
                                                        (vm_ref, str(excep))

        # Delete the folder holding the VM related content on the datastore.
        try:
            dir_ds_compliant_path = build_datastore_path(
                                                datastore_name,
                                                os.path.dirname(vmx_file_path))
            print("Deleting contents of the VM %s from "
                  "datastore %s.") % (vm_name, datastore_name)
            delete_task = session._call_method(session._get_vim(),
                        "DeleteDatastoreFile_Task",
                        session._get_vim().get_service_content().fileManager,
                        name=dir_ds_compliant_path)
            if wait_for_task(session, delete_task) == False:
                print("Failed to delete VM %s from datastore %s") % \
                                                    (vm_name, datastore_name)
        except Exception, excep:
            print("Exception while cleaning up the datastore "
                  "for VM %s : %s") % (vm_name, str(excep))

    except Exception, exc:
        print("Exception : %s") % str(exc)


def split_datastore_path(datastore_path):
    """
    Split the VMWare style datastore path to get the Datastore
    name and the entity path.
    """
    spl = datastore_path.split('[', 1)[1].split(']', 1)
    path = ""
    if len(spl) == 1:
        datastore_url = spl[0]
    else:
        datastore_url, path = spl
    return datastore_url, path.strip()


def build_datastore_path(datastore_name, path):
    """Build the datastore compliant path."""
    return "[%s] %s" % (datastore_name, path)


def create_vswitch_bridge_spec(client_factory, nicDevice=None):
    """ Creates an object of type HostVirtualSwitchSimpleBridge."""
    # This object used to attach a physical NIC to a vSwitch.
    bridge = client_factory.create('ns0:HostVirtualSwitchBondBridge')
    bridge.nicDevice = nicDevice
    return bridge


##############################
#create_HostVirtualSwitchSpec
#Input:
#Output:
#What it does:
#	Creates a spec of type HostVirtualSwitchSpec.
#Ref link for spec:
#http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.VirtualSwitch.Specification.html
##############################
def create_HostVirtualSwitchSpec(client_factory, num_ports=16, bridge=None, policy=None):
    """Builds the config spec to create a vSwitch in the ESX host."""
    vswitch_config_spec = \
        client_factory.create('ns0:HostVirtualSwitchSpec')

    vswitch_config_spec.bridge = bridge
    vswitch_config_spec.policy = policy
    vswitch_config_spec.numPorts = num_ports 
    return vswitch_config_spec 


##################
#delete_portgroup()
#Input: port group name
#Output: none
#What it does:
#	Deletes a Port Group of the specified name.
##################
def delete_vm_port_group(session, hns_ref, port_grp_name):
    """ Deletes a port group of the specified name """
    del_port_grp_task = session._call_method(session._get_vim(),
                           "RemovePortGroup", hns_ref,
                           pgName=port_grp_name)
    return


##################
#delete_vswitch()
#Input: switch name
#Output: none
#What it does:
#	Deletes a Virtual Switch of the specified name.
##################
def delete_vswitch(session, hns_ref, vswitch_name):
    """ Deletes a vswitch of the specified name passed in as vswitch_name """
    del_switch_task = session._call_method(session._get_vim(),
                           "RemoveVirtualSwitch", hns_ref,
                           vswitchName=vswitch_name)
    return


################
#add_vswitch()
#Input:
#Output:
#What it does:
#	First, prepares a spec of type HostVirtualSwitchSpec.
#	Then passes it to the AddVirtualSwitch() SOAP call.
#Ref link for function and Spec:
#http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.NetworkSystem.html#addVirtualSwitch
################
def add_vswitch(session, client_factory, hns_ref, vswitch_name, num_ports, bridge=None, \
		    policy=None):
    """ Creates a spec for the VirtualSwitch to be created, and passes it to the API AddVirtualSwitch """
    vswitch_spec = \
            create_HostVirtualSwitchSpec(client_factory, num_ports, bridge, policy)
    #The AddVirtualSwitch SOAP call takes three parameters -
    #_this : type ManagedObjectReference : A reference to the HostNetworkSystem used to make the method call
    #vswitchName : type xsd:string : A name for the vSwitch to be created
    #spec : type HostVirtualSwitchSpec : The spec file we just created above.
    #So, we need to create a reference to an object of type HostNetworkSystem and use it to make a call to
    #AddVirtualSwitch.

    params = {"vswitchName" : vswitch_name,
              "spec" : vswitch_spec}

    switch_config_task = session._call_method(session._get_vim(),
                           "AddVirtualSwitch", hns_ref,
                           vswitchName=vswitch_name, spec=vswitch_spec)

    return


def create_HostNicTeamingPolicy(client_factory):
    """ Returns an object of type HostNicTeamingPolicy """
    # For now, just leave all params empty in this spec.
    host_nic_teaming_policy = \
        client_factory.create('ns0:HostNicTeamingPolicy')

    return host_nic_teaming_policy


def create_HostNetworkPolicy(client_factory, nicTeaming=None, offloadPolicy=None, security=None, shapingPolicy=None):
    """ Creates an objec of type HostNetworkPolicy """
    host_network_policy = \
        client_factory.create('ns0:HostNetworkPolicy')

    #host_network_policy_spec.nicTeaming = create_HostNicTeamingPolicy(client_factory)
    return host_network_policy


def create_HostPortGroupSpec(client_factory, vswitch_name, port_grp_name, vlan_id=0, policy=None):
    """Builds the config spec to create a vSwitch in the ESX host."""
    print "creating spec.."
    vm_port_grp_spec = \
        client_factory.create('ns0:HostPortGroupSpec')

    vm_port_grp_spec.name = port_grp_name
    vm_port_grp_spec.vlanId = vlan_id
    vm_port_grp_spec.vswitchName = vswitch_name

    # Create a host network policy.
    #vm_port_grp_spec.policy = create_HostNetworkPolicy(client_factory) 
    obj = client_factory.create('ns0:HostNetworkPolicy')

    obj.nicTeaming = client_factory.create('ns0:HostNicTeamingPolicy')
    obj.offloadPolicy = client_factory.create('ns0:HostNetOffloadCapabilities')
    obj.security = client_factory.create('ns0:HostNetworkSecurityPolicy')
    obj.shapingPolicy = client_factory.create('ns0:HostNetworkTrafficShapingPolicy')
    obj.nicTeaming.failureCriteria = client_factory.create('ns0:HostNicFailureCriteria')
    obj.nicTeaming.nicOrder = client_factory.create('ns0:HostNicOrderPolicy')

    vm_port_grp_spec.policy = ""

    return vm_port_grp_spec


def create_vm_port_group(session, client_factory, hns_ref, vswitch_name, port_grp_name, vlan_id=0, policy=None):
    """ Creates a Virtual Machine Port Group in a Virtual Switch """
    # This function will create a Virtual Machine Port Group of the specified name
    # within a specified Virtual Switch.
    # The function we invoke is HostNetworkSystem.AddPortGroup. Refer to
    # http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.NetworkSystem.html#addPortGroup
    # for details on the function. It takes two arguments - one is the reference to the object
    # invoking the AddPortGroup function (it is of type HostNetworkSystem as specified in the
    # function signature in the link above. The other is a spec of type HostPortGroupSpec. Note that
    # the name of the argument is "portgrp" in the parameters list, and we need to specify that name
    # when sending the spec to _call_method(), in the kwargs.

    vm_port_grp_spec = \
            create_HostPortGroupSpec(client_factory, vswitch_name, port_grp_name, vlan_id, policy)

    # Issue the SOAP call using the generic _call_method() handler.
    port_grp_config_task = session._call_method(session._get_vim(),
                           "AddPortGroup", hns_ref,
                           portgrp=vm_port_grp_spec)

    # AddPortGroup doesn't have a return value, so we don't wait on a task like we do for
    # ReconfigVM_Task.
    return


def create_HostIpConfig(client_factory, dhcp_flag=True, ipAddress=None, subnetMask=None):
    """ Creates an object of type HostIpConfig """
    # Refer to -
    # http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.IpConfig.html
    # for specification of this spec.

    hostip_conf_obj = \
	client_factory.create('ns0:HostIpConfig')
    hostip_conf_obj.dhcp = dhcp_flag
    hostip_conf_obj.ipAddress = ipAddress
    hostip_conf_obj.subnetMask = subnetMask

    return hostip_conf_obj


def create_HostVirtualNicSpec(client_factory, ip=None, mac=None):
    """ Creates a spec of type HostVirtualNicSpec """
    # Refer to -
    # http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.VirtualNic.Specification.html
    # for specification of this spec.

    print "Creating HostVirtualNicSpec..."
    vmkernel_port_spec = \
        client_factory.create('ns0:HostVirtualNicSpec')
    print "Done Creating HostVirtualNicSpec..."
    if (ip == None):
        vmkernel_port_spec.ip = ""
    else:
        vmkernel_port_spec.ip = ip

    vmkernel_port_spec.mac = mac

    return vmkernel_port_spec
    

def delete_vm_kernel_port(session, hns_ref, vm_kernel_port_name):
    """ Deletes a vm kernel port given its name """
    service_console_nic_device = session._call_method(session._get_vim(),
        "RemoveVirtualNic", hns_ref,
        device= vm_kernel_port_name)
    return


def create_vm_kernel_port(session, client_factory, hns_ref, vswitch_name, port_grp_name, vmkernel_port_ip, vmkernel_port_netmask, dhcp_flag, vmkernel_port_mac):
    """ Creates a VM kernel port in a Port Group """
    # This function creates a VM kernel port within a specified vswitch's port group.

    # We need to issue the AddVirtualNic SOAP call for this.
    # See -
    # http://pubs.vmware.com/vi3/sdk/ReferenceGuide/vim.host.NetworkSystem.html#addVirtualNic
    # for the signature of this call. It takes 3 parameters -
    # 	_this (type HostNetworkSystem),
    #	portgroup (type xsd:string)
    # 	nic (type HostVirtualNicSpec).

    # Initialize the third parameter - the spec. The spec has two fields. One is mac (xsd:string), the other is
    # of type HostIpConfig. First create a HostIpConfig object.
    ip = create_HostIpConfig(client_factory, dhcp_flag, vmkernel_port_ip, vmkernel_port_netmask)
    vm_kernel_port_spec = \
	create_HostVirtualNicSpec(client_factory, ip, vmkernel_port_mac)

    if (port_grp_name == None):
	p_g_name = None 
    else:
	p_g_name = port_grp_name

    service_console_nic_device = session._call_method(session._get_vim(),
                           "AddVirtualNic", hns_ref,
                           portgroup=p_g_name, nic=vm_kernel_port_spec)
    #service_console_nic_device = session._call_method(session._get_vim(),
    #                       "AddServiceConsoleVirtualNic", hns_ref,
    #                       portgroup=p_g_name, nic=vm_kernel_port_spec)

    return service_console_nic_device

