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

import random
import string
from subprocess import PIPE
from subprocess import Popen
import uuid

from deploy_vpx.flags import FLAGS


def get_random_string(length=FLAGS.RANDOM_STRING_LENGTH):
    char_set = string.ascii_uppercase + string.digits
    return ''.join(random.sample(char_set, length))


def get_uuid():
    """Uses uuid utility to generate unique GUID."""
    return str(uuid.uuid4())

def get_unique_vm_name(algorithm='random'):
    """Returns arguably unique name for VM."""
    host_uuid = get_uuid()
    if algorithm == 'uuid':
        return FLAGS.PREFIX + host_uuid
    else:
        return FLAGS.PREFIX + get_random_string()


def get_upload_file_size(ovf_import_result):
    """Used to calculate upload progress of task. 
    TODO: Extend httpnfclease to ensure that lease doesn't expire 
    until the upload finishes."""
    total_size = 0
    for file_item in ovf_import_result.fileItem:
        total_size = total_size + file_item.size
        #print_ovffile_info(file_item)
    return total_size


def get_path_prefix(file_path):
    """Returns the absolute path of files to be uploaded to host.
    Check for '/' to detected non-unix variants."""
    DELIM = '/'
    if file_path.__len__() > 0:
        if file_path[0] != '/':
            DELIM = '\\'
    else:
        return file_path
    return file_path[0:file_path.rfind(DELIM)] + DELIM
