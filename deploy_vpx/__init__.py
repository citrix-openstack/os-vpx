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

"""
:mod:`deploy_vpx` - Module to deploy VPX on ESXi server
=======================================================
"""
import atexit

import VIAPI

class ViapiPasswordUnconfigured(Exception):
    pass


def login(host_ip, host_password, host_user='root'):
    ip = host_ip
    username = host_user
    password = host_password
    if not password:
        raise ViapiPasswordUnconfigured()
    return _login(ip, username, password)


def _login(ip, username, password, api_retry_count=10, scheme="https"):
    session = VIAPI.VMWareAPISession(ip, username, password,
                               api_retry_count, scheme)
    atexit.register(lambda: cleanup())
    return session

def cleanup():
    pass
