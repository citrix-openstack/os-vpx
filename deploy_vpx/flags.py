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

class FLAGS(object):
    """Class to manage the flags used during vpx deployment on ESXi."""
    GEPPETTO_NETWORK_INTERFACE = 'vmnic1'
    WSDL_LOCATION = 'file:///etc/openstack/sdk/vimService.wsdl'
    DEFAULT_USER = 'root'
    CHUNK_SIZE = 65536
    USER_AGENT = "Olympus Deployment Agent"
    HOST_NETWORK_NAME = 'Olympus Host Network'
    MANAGEMENT_NETWORK_NAME = 'Olympus Management Network'
    PREFIX = 'os-vpx-'
    RANDOM_STRING_LENGTH = 7
