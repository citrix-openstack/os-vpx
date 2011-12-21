#!/usr/bin/python
# Copyright (c) Citrix Systems, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; version 2.1 only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# LocalISOSR: Local ISO storage repository

import os
import re
import string
import xmlrpclib

import XenAPI

import SR
import SRCommand
import VDI
import util
import xs_errors


CAPABILITIES = ["VDI_CREATE", "VDI_DELETE", "VDI_ATTACH", "VDI_DETACH",
                "SR_SCAN", "SR_ATTACH", "SR_DETACH"]


CONFIGURATION = [
         ['location', 'path to mount (required)'],
    ]


DRIVER_INFO = {
    'name': 'LocalISO',
    'description': 'Handles ISO files locally on the filesystem',
    'vendor': 'Citrix Systems',
    'copyright': 'Copyright (c) Citrix Systems, Inc.',
    'driver_version': '1.0',
    'required_api_version': '1.0',
    'capabilities': CAPABILITIES,
    'configuration': CONFIGURATION
    }


TYPE = "localiso"


filename_regex = re.compile("\.iso$|\.img$", re.I)
vdi_path_regex = re.compile("[a-z0-9.-]+\.(iso|img)", re.I)
uuid_file_regex = re.compile(
    "([0-9a-f]{8}-(([0-9a-f]{4})-){3}[0-9a-f]{12})\.(iso|img)", re.I)


def is_image_utf8_compatible(s):
    if filename_regex.search(s) == None:
        return False

    # Check for extended characters
    if type(s) == str:
        try:
            s.decode('utf-8')
        except UnicodeDecodeError, e:
            util.SMlog("WARNING: This string is not UTF-8 compatible.")
            return False
    return True


class LocalISOSR(SR.SR):
    """Local ISO storage repository"""

    def _loadvdis(self):
        """Scan the directory and get uuids either from the VDI filename,
        or by creating a new one."""
        if self.vdis:
            return

        for name in filter(is_image_utf8_compatible,
                           util.listdir(self.path, quiet=True)):
            self.vdis[name] = LocalISOVDI(self, name)
            # Set the VDI UUID if the filename is of the correct form.
            # Otherwise, one will be generated later in VDI._db_introduce.
            m = uuid_file_regex.match(name)
            if m:
                self.vdis[name].uuid = m.group(1)

        # Synchronise the read-only status with existing VDI records
        __xenapi_records = util.list_VDI_records_in_sr(self)
        __xenapi_locations = {}
        for vdi in __xenapi_records.keys():
            __xenapi_locations[__xenapi_records[vdi]['location']] = vdi
        for vdi in self.vdis.values():
            if vdi.location in __xenapi_locations:
                v = __xenapi_records[__xenapi_locations[vdi.location]]
                sm_config = v['sm_config']
                if 'created' in sm_config:
                    vdi.sm_config['created'] = sm_config['created']
                    vdi.read_only = False

    def handles(type):
        """Do we handle this type?"""
        if type == TYPE:
            return True
        return False
    handles = staticmethod(handles)

    def content_type(self, sr_uuid):
        """Returns the content_type XML"""
        return super(LocalISOSR, self).content_type(sr_uuid)

    def vdi(self, uuid):
        """Create a VDI class.  If the VDI does not exist, we determine
        here what its filename should be."""

        filename = util.to_plain_string(self.srcmd.params.get('vdi_location'))
        if filename is None:
            smconfig = self.srcmd.params.get('vdi_sm_config')
            if smconfig is None:
                # uh, oh, a VDI.from_uuid()
                _VDI = self.session.xenapi.VDI
                try:
                    vdi_ref = _VDI.get_by_uuid(uuid)
                except XenAPI.Failure, e:
                    if e.details[0] != 'UUID_INVALID':
                        raise
                else:
                    filename = _VDI.get_location(vdi_ref)

        if filename is None:
            # Get the filename from sm-config['path'], or use the UUID
            # if the path param doesn't exist.
            if smconfig and 'path' in smconfig:
                filename = smconfig['path']
                if not vdi_path_regex.match(filename):
                    raise xs_errors.XenError('VDICreate',
                                             opterr='Invalid path "%s"' \
                                             % filename)
            else:
                filename = '%s.img' % uuid

        return LocalISOVDI(self, filename)

    def load(self, sr_uuid):
        """Initialises the SR"""
        if not 'location' in self.dconf:
            raise xs_errors.XenError('ConfigLocationMissing')

        self.path = util.to_plain_string(self.dconf['location'])
        self.sr_vditype = 'file'

    def create(self, sr_uuid, size):
        pass

    def attach(self, sr_uuid):
        """Std. attach"""
        pass

    def detach(self, sr_uuid):
        """Std. detach"""
        pass

    def scan(self, sr_uuid):
        """Scan: see _loadvdis"""
        if not util.isdir(self.path):
            return

        self._loadvdis()
        self.physical_size = util.get_fs_size(self.path)
        self.physical_utilisation = util.get_fs_utilisation(self.path)
        self.virtual_allocation = self._sum_vdis()

        return super(LocalISOSR, self).scan(sr_uuid)

    def _sum_vdis(self):
        result = 0L
        for vdi in self.vdis.values():
            result += vdi.size
        return result


class LocalISOVDI(VDI.VDI):
    def load(self, vdi_uuid):
        # Nb, in the vdi_create call, the filename is unset, so the following
        # will fail.
        self.vdi_type = "iso"
        try:
            stat = os.stat(self.path)
            self.utilisation = long(stat.st_size)
            self.size = long(stat.st_size)
            self.label = self.filename
        except:
            pass

    def __init__(self, mysr, filename):
        self.path = os.path.join(mysr.path, filename)
        VDI.VDI.__init__(self, mysr, None)
        self.location = filename
        self.filename = filename
        self.read_only = True
        self.label = filename
        self.sm_config = {}

    def detach(self, sr_uuid, vdi_uuid):
        pass

    def attach(self, sr_uuid, vdi_uuid):
        try:
            os.stat(self.path)
            return super(LocalISOVDI, self).attach(sr_uuid, vdi_uuid)
        except:
            raise xs_errors.XenError('VDIMissing')

    def create(self, sr_uuid, vdi_uuid, size):
        self.uuid = vdi_uuid
        self.path = os.path.join(self.sr.path, self.filename)
        self.size = size
        self.utilisation = size
        self.read_only = False
        self.label = self.filename
        self.sm_config = self.sr.srcmd.params['vdi_sm_config']
        self.sm_config['created'] = util._getDateString()

        if util.pathexists(self.path):
            raise xs_errors.XenError('VDIExists')

        try:
            handle = open(self.path, 'w')
            handle.truncate(size)
            handle.close()
            self._db_introduce()
            return super(LocalISOVDI, self).get_params()
        except Exception, exn:
            util.SMlog("Exception when creating VDI: %s" % exn)
            raise xs_errors.XenError('VDICreate', \
                     opterr='could not create file: "%s"' % self.path)

    def delete(self, sr_uuid, vdi_uuid):
        util.SMlog("Deleting...")

        self.uuid = vdi_uuid
        self._db_forget()

        if not util.pathexists(self.path):
            return

        try:
            util.SMlog("Unlinking...")
            os.unlink(self.path)
            util.SMlog("Done...")
        except:
            raise xs_errors.XenError('VDIDelete')

    # Update, introduce unimplemented. super class will raise
    # exceptions

if __name__ == '__main__':
    SRCommand.run(LocalISOSR, DRIVER_INFO)
else:
    SR.registerSR(LocalISOSR)
