ifdef B_BASE
USE_BRANDING := yes
IMPORT_BRANDING := yes
NO_DEFAULT_BUILD := yes
include $(B_BASE)/common.mk
include $(B_BASE)/rpmbuild.mk
REPO := /repos/os-vpx
NOVA_REPO := /repos/nova
NOVA_BUILD_REPO := /repos/nova-build
GLANCE_BUILD_REPO := /repos/glance-build
SWIFT_BUILD_REPO := /repos/swift-build
KEYSTONE_BUILD_REPO := /repos/keystone-build
GEPPETTO_REPO := /repos/geppetto
else
COMPONENT := os-vpx
include ../../mk/easy-config.mk
REPO := .
NOVA_REPO := ../nova
NOVA_BUILD_REPO := ../nova-build
GLANCE_BUILD_REPO := ../glance-build
SWIFT_BUILD_REPO := ../swift-build
KEYSTONE_BUILD_REPO := ../keystone-build
GEPPETTO_REPO := ../geppetto
endif

VENDOR_CODE := xs
VENDOR_NAME := "Citrix Systems, Inc."
LABEL := xenserver-openstack
TEXT := XenServer OpenStack
VPX_LABEL := xenserver-openstack-vpx
VPX_TEXT := XenServer OpenStack VPX
VERSION := $(PRODUCT_VERSION)
BUILD := $(BUILD_NUMBER)
VERSION_BUILD := $(VERSION)-$(BUILD)

FS_SIZE_MIB ?= 1200
DEVEL_FS_SIZE_MIB ?= 2000

include $(REPO)/make-vpx.mk

PLUGIN_SRC := $(NOVA_REPO)/upstream/plugins/xenserver/xenapi
NETWORKING_SRC := $(NOVA_REPO)/upstream/plugins/xenserver/networking
VIF_PATCH := $(REPO)/xenserver-openstack/vif-6.0.patch
XENSERVER_OPENSTACK_OVERLAY := $(REPO)/xenserver-openstack/overlay

EPEL_RPM_DIR := $(CARBON_DISTFILES)/epel5
EPEL_YUM_DIR := $(MY_OBJ_DIR)/epel5

RPMFORGE_RPM_DIR := $(CARBON_DISTFILES)/rpmforge
RPMFORGE_YUM_DIR := $(MY_OBJ_DIR)/rpmforge

GU_RPM_DIR := $(CARBON_DISTFILES)/openstack/xe-guest-utilities
GU_YUM_DIR := $(MY_OBJ_DIR)/guest-utilities-yum
GU_RPM_VER := 6.0.0-743

XE_CLI_RPM_DIR := $(CARBON_DISTFILES)/openstack/xe-cli
XE_CLI_YUM_DIR := $(MY_OBJ_DIR)/xe-cli
XE_CLI_RPM_VER := 6.0.0-50734p

RSYNC_RPM_DIR := $(CARBON_DISTFILES)/rsync
RSYNC_YUM_DIR := $(MY_OBJ_DIR)/rsync
RSYNC_RPM_VER := 3.0.7-1.el5.rfx

BUGTOOL_SPEC := $(MY_OBJ_DIR)/os-vpx-bugtool.spec
BUGTOOL_RPM := $(MY_OBJ_DIR)/os-vpx-rpms/RPMS/noarch/os-vpx-bugtool-$(VERSION_BUILD).noarch.rpm

SCRIPTS_SPEC := $(MY_OBJ_DIR)/os-vpx-scripts.spec
SCRIPTS_RPM := $(MY_OBJ_DIR)/os-vpx-rpms/RPMS/noarch/os-vpx-scripts-$(VERSION_BUILD).noarch.rpm

SCRIPTS_DEB := $(MY_OBJ_DIR)/os-vpx-debs/os-vpx-scripts-$(VERSION_BUILD).deb

SUPP_PACK_TARBALL := $(MY_OBJ_DIR)/xenserver-openstack.tar.gz
SUPP_PACK_ISO_TMP := $(MY_OBJ_DIR)/xenserver-openstack.iso
SUPP_PACK_STAGING_DIR := $(MY_OBJ_DIR)/os-supp-pack
VPX_SUPP_PACK_TARBALL := $(MY_OBJ_DIR)/xenserver-openstack-vpx.tar.gz
VPX_SUPP_PACK_ISO_TMP := $(MY_OBJ_DIR)/xenserver-openstack-vpx.iso
VPX_SUPP_PACK_STAGING_DIR := $(MY_OBJ_DIR)/os-vpx-supp-pack
VPX_STAGING_DIR := $(MY_OBJ_DIR)/os-vpx
VPX_DEVEL_STAGING_DIR := $(MY_OBJ_DIR)/os-vpx-devel
VPX_UBUNTU_STAGING_DIR := $(MY_OBJ_DIR)/os-vpx-ubuntu

VPX_SUPP_PACK_REPODATA_IN := $(REPO)/xenserver-openstack-vpx.repodata.in
VPX_SUPP_PACK_REPODATA := $(MY_OBJ_DIR)/xenserver-openstack-vpx.repodata

RPM_RPMSDIR := $(MY_OBJ_DIR)/RPMS
RPM_BUILD_DIRECTORY := $(MY_OBJ_DIR)/RPM_BUILD_DIRECTORY

PLUGIN_SPEC := $(MY_OBJ_DIR)/xenserver-openstack.spec
PLUGIN_RPM := $(RPM_RPMSDIR)/noarch/xenserver-openstack-$(VERSION_BUILD).noarch.rpm

OS_VPX_SPEC := $(MY_OBJ_DIR)/xenserver-os-vpx.spec
OS_VPX_RPM := $(RPM_RPMSDIR)/noarch/xenserver-os-vpx-$(VERSION_BUILD).noarch.rpm

BUGTOOL_ALL_SPEC := $(MY_OBJ_DIR)/os-vpx-bugtool-all.spec
BUGTOOL_ALL_RPM := $(RPM_RPMSDIR)/noarch/os-vpx-bugtool-all-$(VERSION_BUILD).noarch.rpm

NETADDR_RPM := $(CARBON_DISTFILES)/epel5/python-netaddr-0.5.2-1.el5.noarch.rpm
NETADDR_SRPM := $(CARBON_DISTFILES)/epel5/python-netaddr-0.5.2-1.el5.src.rpm

VPX_CHROOT_STAMP := $(VPX_STAGING_DIR)/.vpx-chroot
VPX_EASY_INSTALL_STAMP := $(VPX_STAGING_DIR)/.vpx-easy_install
VPX_OVERLAY_STAMP := $(VPX_STAGING_DIR)/.vpx-overlay
VPX_DEVEL_STAMP := $(VPX_STAGING_DIR)/.vpx-devel
VPX_UBUNTU_CHROOT_STAMP := $(VPX_UBUNTU_STAGING_DIR)/.vpx-ubuntu-chroot
VPX_UBUNTU_OVERLAY_STAMP := $(VPX_UBUNTU_STAGING_DIR)/.vpx-ubuntu-overlay

SUPP_PACK_ISO := $(MY_OUTPUT_DIR)/xenserver-openstack-supp-pack.iso
SUPP_PACK_DIR := $(MY_OUTPUT_DIR)/packages.openstack
VPX_SUPP_PACK_ISO := $(MY_OUTPUT_DIR)/xenserver-openstack-vpx-supp-pack.iso
VPX_SUPP_PACK_DIR := $(MY_OUTPUT_DIR)/packages.openstack-vpx
XVA := $(MY_OUTPUT_DIR)/os-vpx.xva
OVF_DIR := $(MY_OUTPUT_DIR)/os-vpx
OVF := $(OVF_DIR)/os-vpx.ovf
XVA_DEVEL := $(MY_OUTPUT_DIR)/os-vpx-devel.xva
OVF_DEVEL_DIR := $(MY_OUTPUT_DIR)/os-vpx-devel
OVF_DEVEL := $(OVF_DEVEL_DIR)/os-vpx-devel.ovf
XVA_UBUNTU := $(MY_OUTPUT_DIR)/os-vpx-ubuntu.xva
OVF_UBUNTU_DIR := $(MY_OUTPUT_DIR)/os-vpx-ubuntu
OVF_UBUNTU := $(OVF_UBUNTU_DIR)/os-vpx-ubuntu.ovf
PLUGIN_RPM_LINK := $(MY_OUTPUT_DIR)/xenserver-openstack.noarch.rpm
BUGTOOL_ALL_RPM_LINK := $(MY_OUTPUT_DIR)/os-vpx-bugtool-all.noarch.rpm
INSTALL_SH := $(MY_OUTPUT_DIR)/install-os-vpx.sh
UNINSTALL_SH := $(MY_OUTPUT_DIR)/uninstall-os-vpx.sh
CREATE_ISO_SR_SH := $(MY_OUTPUT_DIR)/xs-iso-sr-create.sh
ESX_DEPLOY_TOOLS_DIR := $(MY_OUTPUT_DIR)/deploy_tools
ESX_INSTALL_SCRIPT := $(ESX_DEPLOY_TOOLS_DIR)/install-os-vpx-esxi.py
ESX_UNINSTALL_SCRIPT := $(ESX_DEPLOY_TOOLS_DIR)/uninstall-os-vpx-esxi.py
ESX_NETWORK_SETUP_SCRIPT := $(ESX_DEPLOY_TOOLS_DIR)/setup_esxi_networking.py
ESX_NETWORK_UNINSTALL_SCRIPT := $(ESX_DEPLOY_TOOLS_DIR)/delete_esxi_networking.py
BUILD_NUMBER_FILE := $(MY_OUTPUT_DIR)/BUILD_NUMBER
SOURCES := $(MY_SOURCES)/os-vpx-sources.iso

ESX_DEPLOY_VPX_SOURCES := $(shell find deploy_vpx -type f)
$(ESX_DEPLOY_TOOLS_DIR)/deploy_vpx/%: $(REPO)/deploy_vpx/%
	mkdir -p $(dir $@)
	cp $< $@

ESX_DEPLOY_TOOLS := $(patsubst %,$(ESX_DEPLOY_TOOLS_DIR)/%,$(ESX_DEPLOY_VPX_SOURCES))

SWIFT_RPMS_SRC := $(wildcard $(PROJECT_OUTPUTDIR)/swift/RPMS/noarch/*.rpm)
SWIFT_RPMS := $(patsubst $(PROJECT_OUTPUTDIR)/swift/%,$(PROJECT_OUTPUTDIR)/os-vpx/%,$(SWIFT_RPMS_SRC))

PACKAGES_LIST := $(MY_OUTPUT_DIR)/os-vpx-packages.txt

DEPS_DOT := $(MY_OUTPUT_DIR)/os-vpx-deps.dot
DEPS_PNG := $(MY_OUTPUT_DIR)/os-vpx-deps.png

SUPPACK_OUTPUT := $(SUPP_PACK_ISO) $(SUPP_PACK_DIR)/XS-PACKAGES
VPX_SUPP_PACK_OUTPUT := $(VPX_SUPP_PACK_ISO) $(VPX_SUPP_PACK_DIR)/XS-PACKAGES

VPX_TYPES ?= xva:ovf
VPXS_ONLY ?=
DEVEL_ONLY ?=

$(shell echo "QUICK=$(QUICK)" >&2)
$(shell echo "VPX_TYPES=$(VPX_TYPES)" >&2)

OUTPUT_VPXS :=
OUTPUT_UBUNTU :=
ifeq ($(DEVEL_ONLY),)
$(shell echo "DEVEL_ONLY mode off" >&2)
ifneq (,$(findstring xva,$(VPX_TYPES)))
OUTPUT_VPXS += $(XVA) $(XVA_DEVEL)
OUTPUT_UBUNTU += $(XVA_UBUNTU)
endif
ifneq (,$(findstring ovf,$(VPX_TYPES)))
OUTPUT_VPXS += $(OVF) $(OVF_DEVEL)
OUTPUT_UBUNTU += $(OVF_UBUNTU)
endif
else
$(shell echo "DEVEL_ONLY mode on" >&2)
ifneq (,$(findstring xva,$(VPX_TYPES)))
OUTPUT_VPXS += $(XVA_DEVEL)
endif
ifneq (,$(findstring ovf,$(VPX_TYPES)))
OUTPUT_VPXS += $(OVF_DEVEL)
endif
endif

ifeq ($(VPXS_ONLY),)
$(shell echo "VPXS_ONLY mode off" >&2)
OUTPUT := $(OUTPUT_VPXS) \
         $(PLUGIN_RPM_LINK) \
         $(BUGTOOL_ALL_RPM_LINK) \
         $(INSTALL_SH) $(UNINSTALL_SH) \
         $(CREATE_ISO_SR_SH) \
         $(ESX_DEPLOY_TOOLS) \
         $(ESX_INSTALL_SCRIPT) $(ESX_UNINSTALL_SCRIPT) \
         $(ESX_NETWORK_SETUP_SCRIPT) \
         $(ESX_NETWORK_UNINSTALL_SCRIPT) \
         $(DEPS_DOT) $(DEPS_PNG) \
         $(PACKAGES_LIST) \
         $(BUILD_NUMBER_FILE) \
         $(SOURCES) \
         $(SUPPACK_OUTPUT) \
         $(VPX_SUPP_PACK_OUTPUT) \
         $(SWIFT_RPMS)
else
$(shell echo "VPXS_ONLY mode on" >&2)
OUTPUT := $(OUTPUT_VPXS)
endif


VPX_OUTPUTS := $(shell echo "$(VPX_TYPES)" | \
                       sed -e 's,xva,$(XVA),g' \
                           -e 's,ovf,$(OVF_DIR),g')
VPX_DEVEL_OUTPUTS := $(shell echo "$(VPX_TYPES)" | \
                             sed -e 's,xva,$(XVA_DEVEL),g' \
                                 -e 's,ovf,$(OVF_DEVEL_DIR),g')
VPX_UBUNTU_OUTPUTS := $(shell echo "$(VPX_TYPES)" | \
                             sed -e 's,xva,$(XVA_UBUNTU),g' \
                                 -e 's,ovf,$(OVF_UBUNTU_DIR),g')
VPX_XML := $(shell echo "$(VPX_TYPES)" | \
                       sed -e 's,xva,$(MY_OBJ_DIR)/ova.xml,g' \
                           -e 's,ovf,$(MY_OBJ_DIR)/ovf.xml,g')


with_vars := \
	PRODUCT_VERSION=$(PRODUCT_VERSION) \
	BUILD_NUMBER=$(BUILD_NUMBER) \
	MY_OBJ_DIR=$(MY_OBJ_DIR)


.PHONY: os-vpx
os-vpx: $(OUTPUT)
	@:

.PHONY: os-vpx-ubuntu
os-vpx-ubuntu: $(OUTPUT_UBUNTU)
	@:

$(OVF): $(XVA)
$(XVA): $(MY_OBJ_DIR)/ova.xml $(MY_OBJ_DIR)/ovf.xml $(VPX_OVERLAY_STAMP)
	$(call make-vpx-multiple,$(VPX_TYPES),"$(VPX_XML)","$(VPX_OUTPUTS)",$(VPX_STAGING_DIR)/root,$(FS_SIZE_MIB),$(MY_OBJ_DIR))

$(OVF_DEVEL): $(XVA_DEVEL)
$(XVA_DEVEL): $(MY_OBJ_DIR)/ova.xml $(MY_OBJ_DIR)/ovf.xml $(VPX_DEVEL_STAMP)
	$(call make-vpx-multiple,$(VPX_TYPES),"$(VPX_XML)","$(VPX_DEVEL_OUTPUTS)",$(VPX_DEVEL_STAGING_DIR)/root,$(DEVEL_FS_SIZE_MIB),$(MY_OBJ_DIR))

$(OVF_UBUNTU): $(XVA_UBUNTU)
$(XVA_UBUNTU): $(MY_OBJ_DIR)/ova.xml $(MY_OBJ_DIR)/ovf.xml \
	       $(VPX_UBUNTU_OVERLAY_STAMP)
	$(call make-vpx-multiple,$(VPX_TYPES),"$(VPX_XML)","$(VPX_UBUNTU_OUTPUTS)",$(VPX_UBUNTU_STAGING_DIR),$(FS_SIZE_MIB),$(MY_OBJ_DIR))

$(MY_OBJ_DIR)/ova.xml: $(REPO)/ova.xml.in
	$(call brand,$<) >$@

$(MY_OBJ_DIR)/ovf.xml: $(REPO)/ovf.xml.in
	$(call brand,$<) >$@

$(VPX_DEVEL_STAMP): $(REPO)/build-vpx-devel.sh \
		    $(shell find $(REPO)/overlay-devel -type f) \
		    $(VPX_OVERLAY_STAMP)
	sh $(REPO)/build-vpx-devel.sh
	touch $@

$(VPX_OVERLAY_STAMP): $(REPO)/build-vpx-overlay.sh \
		      $(REPO)/os-vpx.cfg \
		      $(REPO)/udev-xvd.patch \
		      $(shell find $(REPO)/overlay -type f) \
		      $(VPX_EASY_INSTALL_STAMP)
	sh $< $(REPO)/os-vpx.cfg $(VERSION_BUILD)
	touch $@

$(VPX_EASY_INSTALL_STAMP): $(REPO)/build-vpx-easy_install.sh \
			   $(NOVA_BUILD_REPO)/easy_install-nova-deps.sh \
			   $(GLANCE_BUILD_REPO)/easy_install-glance-deps.sh \
			   $(SWIFT_BUILD_REPO)/easy_install-swift-deps.sh \
			   $(KEYSTONE_BUILD_REPO)/easy_install-keystone-deps.sh \
			   $(GEPPETTO_REPO)/easy_install-geppetto-deps.sh \
			   $(REPO)/os-vpx.cfg \
			   $(VPX_CHROOT_STAMP)
	sh $< $(REPO)/os-vpx.cfg $(NOVA_BUILD_REPO) $(GLANCE_BUILD_REPO) \
				 $(SWIFT_BUILD_REPO) $(KEYSTONE_BUILD_REPO) \
				 $(GEPPETTO_REPO)
	touch $@

$(VPX_CHROOT_STAMP): $(REPO)/os-vpx.cfg $(REPO)/vpx-chroot/* \
		     $(GU_YUM_DIR)/repodata/repomd.xml \
		     $(XE_CLI_YUM_DIR)/repodata/repomd.xml \
		     $(EPEL_YUM_DIR)/repodata/repomd.xml \
		     $(RPMFORGE_YUM_DIR)/repodata/repomd.xml \
		     $(RSYNC_YUM_DIR)/repodata/repomd.xml \
	             $(BUGTOOL_RPM) \
	             $(SCRIPTS_RPM) \
		     $(shell find $(PROJECT_OUTPUTDIR)/packages -type f) \
		     $(shell find $(PROJECT_OUTPUTDIR)/nova -type f) \
		     $(shell find $(PROJECT_OUTPUTDIR)/swift -type f) \
		     $(shell find $(PROJECT_OUTPUTDIR)/glance -type f) \
		     $(shell find $(PROJECT_OUTPUTDIR)/keystone -type f) \
		     $(shell find $(PROJECT_OUTPUTDIR)/geppetto -type f)
	$(call make-chroot,$(@D),$<)
	touch $@

$(VPX_UBUNTU_OVERLAY_STAMP): $(REPO)/build-vpx-overlay.sh \
			     $(shell find $(REPO)/overlay -type f) \
			     $(SCRIPTS_DEB) \
			     $(VPX_UBUNTU_CHROOT_STAMP)
	$(EATMYDATA) $(SUDO) bash $< '' $(VERSION_BUILD) $(@D) $(SCRIPTS_DEB)
	$(SUDO) touch $@

$(VPX_UBUNTU_CHROOT_STAMP): $(REPO)/vpx-chroot/* \
			    $(REPO)/vpx-packages.txt \
			    $(shell find $(PROJECT_OUTPUTDIR)/packages -type f) \
			    $(shell find $(PROJECT_OUTPUTDIR)/nova -type f) \
			    $(shell find $(PROJECT_OUTPUTDIR)/swift -type f) \
			    $(shell find $(PROJECT_OUTPUTDIR)/glance -type f) \
			    $(shell find $(PROJECT_OUTPUTDIR)/keystone -type f) \
			    $(shell find $(PROJECT_OUTPUTDIR)/geppetto -type f)
	$(call make-ubuntu-chroot,$(@D),$(REPO)/vpx-packages.txt)
	$(SUDO) touch $@

$(BUGTOOL_RPM): $(REPO)/build-script-rpm.sh $(BUGTOOL_SPEC) \
		$(shell find $(REPO)/os-vpx-bugtool -type f)
	sh $< $(BUGTOOL_SPEC) $(REPO)/os-vpx-bugtool $@

$(SCRIPTS_RPM): $(REPO)/build-script-rpm.sh $(SCRIPTS_SPEC) \
		$(shell find $(REPO)/os-vpx-scripts -type f)
	sh $< $(SCRIPTS_SPEC) $(REPO)/os-vpx-scripts $@

$(GU_YUM_DIR)/repodata/repomd.xml:
	$(call make-yum-repo,$(GU_YUM_DIR),\
			     $(GU_RPM_DIR)/*$(GU_RPM_VER)* \
			     $(GU_RPM_DIR)/*.src.rpm)

$(XE_CLI_YUM_DIR)/repodata/repomd.xml:
	$(call make-yum-repo,$(XE_CLI_YUM_DIR),\
			     $(XE_CLI_RPM_DIR)/*$(XE_CLI_RPM_VER)* \
			     $(XE_CLI_RPM_DIR)/*.src.rpm)

$(EPEL_YUM_DIR)/repodata/repomd.xml:
	$(call make-yum-repo,$(EPEL_YUM_DIR),$(EPEL_RPM_DIR)/*)

$(RSYNC_YUM_DIR)/repodata/repomd.xml:
	$(call make-yum-repo,$(RSYNC_YUM_DIR),\
			     $(RSYNC_RPM_DIR)/*$(RSYNC_RPM_VER)* \
			     $(RSYNC_RPM_DIR)/*.src.rpm)

$(RPMFORGE_YUM_DIR)/repodata/repomd.xml:
	$(call make-yum-repo,$(RPMFORGE_YUM_DIR),$(RPMFORGE_RPM_DIR)/*)

$(PLUGIN_RPM_LINK): $(SUPP_PACK_DIR)/XS-PACKAGES
	rm -f $@
	ln -s packages.openstack/$(notdir $(PLUGIN_RPM)) $@

$(BUGTOOL_ALL_RPM_LINK): $(SUPP_PACK_DIR)/XS-PACKAGES
	rm -f $@
	ln -s packages.openstack/$(notdir $(BUGTOOL_ALL_RPM)) $@

$(SUPP_PACK_DIR)/XS-PACKAGES: $(SUPP_PACK_TARBALL)
	mkdir -p $(dir $@)
	tar -C $(dir $@) -xzf $<
	rm -f $(dir $@)/{un,}install.sh
	touch $@

$(VPX_SUPP_PACK_DIR)/XS-PACKAGES: $(VPX_SUPP_PACK_TARBALL)
	mkdir -p $(dir $@)
	tar -C $(dir $@) -xzf $<
	rm -f $(dir $@)/{un,}install.sh
	touch $@

$(SUPP_PACK_ISO): $(SUPP_PACK_ISO_TMP)
	cp $< $@

$(SUPP_PACK_ISO_TMP) $(SUPP_PACK_TARBALL): $(PLUGIN_RPM) \
					   $(BUGTOOL_ALL_RPM) $(NETADDR_RPM)
	$(call mkdir_clean,$(SUPP_PACK_STAGING_DIR))
	cp $^ $(SUPP_PACK_STAGING_DIR)
	cd $(SUPP_PACK_STAGING_DIR) && $(REPO)/build-supplemental-pack.sh \
	  --homogeneous \
	  --output=$(dir $(SUPP_PACK_TARBALL)) --tarball \
	  --vendor-code=$(VENDOR_CODE) --vendor-name=$(VENDOR_NAME) \
	  --label=$(LABEL) --text="$(TEXT)" \
	  --version=$(VERSION) --build=$(BUILD) *.rpm

$(VPX_SUPP_PACK_ISO): $(VPX_SUPP_PACK_ISO_TMP)
	cp $< $@

$(VPX_SUPP_PACK_ISO_TMP) $(VPX_SUPP_PACK_TARBALL): $(OS_VPX_RPM) \
						   $(VPX_SUPP_PACK_REPODATA)
	$(call mkdir_clean,$(VPX_SUPP_PACK_STAGING_DIR))
	cp $< $(VPX_SUPP_PACK_STAGING_DIR)
	cd $(VPX_SUPP_PACK_STAGING_DIR) && $(REPO)/build-supplemental-pack.sh \
	  --homogeneous \
	  --repo-data=$(VPX_SUPP_PACK_REPODATA) \
	  --output=$(dir $(VPX_SUPP_PACK_TARBALL)) --tarball \
	  --vendor-code=$(VENDOR_CODE) --vendor-name=$(VENDOR_NAME) \
	  --label=$(VPX_LABEL) --text="$(VPX_TEXT)" \
	  --version=$(VERSION) --build=$(BUILD) *.rpm

$(VPX_SUPP_PACK_REPODATA): $(VPX_SUPP_PACK_REPODATA_IN)
	sed -e 's/@VENDOR_CODE@/$(VENDOR_CODE)/g' \
	    -e 's/@LABEL@/$(LABEL)/g' \
	    -e 's/@PRODUCT_VERSION@/$(PRODUCT_VERSION)/g' $< >$@

$(PLUGIN_RPM): DEST := /etc/xapi.d/plugins
$(PLUGIN_RPM): TMPDIR := $(RPM_BUILD_DIRECTORY)/tmp/xenserver-openstack
$(PLUGIN_RPM): TMPDEST := $(TMPDIR)/$(DEST)
$(PLUGIN_RPM): $(PLUGIN_SPEC) \
	       $(shell find $(PLUGIN_SRC) -type f) \
	       $(shell find $(NETWORKING_SRC) -type f) \
	       $(VIF_PATCH) \
	       $(shell find $(XENSERVER_OPENSTACK_OVERLAY) -type f)
	mkdir -p $(dir $@)
	mkdir -p $(TMPDEST)
	cp $(PLUGIN_SRC)/$(DEST)/* $(TMPDEST)
	chmod a+x $(TMPDEST)/*
	cp -r $(NETWORKING_SRC)/* $(TMPDIR)
	cd $(XENSERVER_OPENSTACK_OVERLAY) && find . -name .\*\~ -o \
	    -exec cp --parents \{\} $(TMPDIR) \;
	cp $(VIF_PATCH) $(TMPDIR)/etc/xensource/scripts/
	$(RPMBUILD) -bb $<

$(OS_VPX_RPM): DEST := /opt/xensource/packages/files/os-vpx
$(OS_VPX_RPM): TMPDIR := $(RPM_BUILD_DIRECTORY)/tmp/xenserver-os-vpx
$(OS_VPX_RPM): TMPDEST := $(TMPDIR)/$(DEST)
$(OS_VPX_RPM): $(OS_VPX_SPEC) $(XVA)
	mkdir -p $(dir $@)
	mkdir -p $(TMPDEST)
	cp xenserver-os-vpx/* $(TMPDEST)
	cp install-os-vpx.sh $(TMPDEST)
	cp uninstall-os-vpx.sh $(TMPDEST)
	cp $(XVA) $(TMPDEST)
	$(RPMBUILD) -bb $<

$(BUGTOOL_ALL_RPM): DEST := /usr/sbin
$(BUGTOOL_ALL_RPM): TMPDIR := $(RPM_BUILD_DIRECTORY)/tmp/os-vpx-bugtool-all
$(BUGTOOL_ALL_RPM): TMPDEST := $(TMPDIR)/$(DEST)
$(BUGTOOL_ALL_RPM): $(BUGTOOL_ALL_SPEC) \
		    $(shell find $(REPO)/os-vpx-bugtool-all -type f)
	mkdir -p $(dir $@)
	mkdir -p $(TMPDEST)
	cp $(REPO)/os-vpx-bugtool-all/os-vpx-bugtool-all $(TMPDEST)
	chmod a+x $(TMPDEST)/*
	$(RPMBUILD) -bb $<

$(MY_OBJ_DIR)/%.spec: %.spec.in
	mkdir -p $(dir $@)
	$(call brand,$^) >$@

$(MY_OBJ_DIR)/%.spec: os-vpx-bugtool/%.spec.in
	mkdir -p $(dir $@)
	$(call brand,$^) >$@

$(MY_OBJ_DIR)/%.spec: os-vpx-bugtool-all/%.spec.in
	mkdir -p $(dir $@)
	$(call brand,$^) >$@

$(MY_OBJ_DIR)/%.spec: os-vpx-scripts/%.spec.in
	mkdir -p $(dir $@)
	$(call brand,$^) >$@

$(INSTALL_SH) $(UNINSTALL_SH) $(CREATE_ISO_SR_SH) : $(MY_OUTPUT_DIR)/%: $(REPO)/%
	cp $< $@
	chmod a+x $@

$(SCRIPTS_DEB): $(shell find $(REPO)/os-vpx-scripts -type f)
	$(with_vars) $(REPO)/os-vpx-scripts/build-deb.sh $@

$(ESX_INSTALL_SCRIPT) $(ESX_UNINSTALL_SCRIPT) $(ESX_NETWORK_SETUP_SCRIPT) $(ESX_NETWORK_UNINSTALL_SCRIPT): $(ESX_DEPLOY_TOOLS_DIR)/%: $(REPO)/%
	mkdir -p $(dir $@)
	cp $< $@
	chmod a+x $@

$(BUILD_NUMBER_FILE):
	echo $(BUILD_NUMBER) >$@

$(SOURCES): $(REPO)/make-sources.sh \
	    $(NETADDR_RPM) \
	    $(shell bash -c 'ls $(PROJECT_OUTPUTDIR)/{glance,nova,packages,swift,keystone}/SRPMS/*')
	sh $< $@ $(VERSION)

$(DEPS_PNG): $(DEPS_DOT)
	dot -Tpng -o $@ $^

$(PACKAGES_LIST): $(DEPS_DOT)
$(DEPS_DOT): $(VPX_CHROOT_STAMP)
	sh make-dep-graph.sh $@ $(PACKAGES_LIST)

.PHONY: vpx-sp
vpx-sp: $(SUPPACK_OUTPUT) $(VPX_SUPP_PACK_OUTPUT)
	@:

$(MY_OUTPUT_DIR)/RPMS/noarch/%.rpm: $(PROJECT_OUTPUTDIR)/swift/RPMS/noarch/%.rpm
	mkdir -p $(dir $@)
	cp -al $< $@

vpx-sp-clean:
	rm -rf $(SUPP_PACK_DIR)
	rm -rf $(SUPP_PACK_STAGING_DIR)
	rm -rf $(VPX_SUPP_PACK_DIR)
	rm -rf $(VPX_SUPP_PACK_STAGING_DIR)
	rm -rf $(MY_OBJ_DIR)/xenserver-os-vpx*
	rm -rf $(SUPP_PACK_ISO)
	rm -rf $(VPX_SUPP_PACK_ISO)
	rm -rf $(RPM_BUILD_DIRECTORY)/tmp/xenserver-os-vpx
	rm -rf $(OS_VPX_RPM)

clean:
	rm -rf $(OVF_DIR) $(OVF_DEVEL_DIR)
	rm -f $(OUTPUT)
	rm -rf $(MY_OBJ_DIR)/*
