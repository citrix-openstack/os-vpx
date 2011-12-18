# make-yum-repo <dest dir> <RPMs> 
make-yum-repo = \
	set -e; \
	$(call mkdir_clean,$(1)); \
	cp -s $(2) $(1); \
	$(EATMYDATA) createrepo $(1)

# make-chroot <staging dir> <config>
make-chroot = \
	$(EATMYDATA) sh $(REPO)/vpx-chroot/make-vpx.sh $(1) $(2)

# make-ubuntu-chroot <staging dir>
make-ubuntu-chroot = \
	$(EATMYDATA) $(SUDO) sh -x $(REPO)/vpx-chroot/make-ubuntu-chroot.sh $(1) $(2)

# make-vpx <staging dir> <fs size MiB> <ova.xml> <tmpdir> <dest>
make-vpx = \
	$(EATMYDATA) bash $(REPO)/mkxva -o "$(5)" -t xva -x "$(3)" $(1)/root $(2) $(4)

make-vpx-partition = \
        $(EATMYDATA) bash $(REPO)/mkxva -p -o "$(5)" -t xva -x "$(3)" $(1)/root $(2) $(4)

make-vpx-multiple = \
        $(EATMYDATA) bash $(REPO)/mkxva -p -t $(1) -x $(2) -o $(3) $(4) $(5) $(6)
