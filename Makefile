KEXTS= \
	EFI/OC/Kexts/Lilu.kext \
	EFI/OC/Kexts/WhateverGreen.kext \
	EFI/OC/Kexts/AppleALC.kext \
	EFI/OC/Kexts/VirtualSMC.kext

DRIVERS= \
	EFI/OC/Drivers/VBoxHfs.efi \
	EFI/OC/Drivers/OpenRuntime.efi \
	EFI/OC/Drivers/OpenCanopy.efi

TOOLS = \
	EFI/OC/Tools/Shell.efi \
	EFI/OC/Tools/ResetSystem.efi

MISC= \
	EFI/BOOT/BOOTx64.efi \
	EFI/OC/OpenCore.efi \
	EFI/OC/Resources

EFI_FILES=$(KEXTS) $(DRIVERS) $(TOOLS) $(MISC) EFI/OC/config.plist

SUBMODULES = \
	src/AppleALC \
	src/Lilu \
	src/WhateverGreen \
	src/OpenCorePkg \
	src/VirtualSMC \
	src/OcBinaryData

# Either DEBUG or RELEASE
OPENCORE_MODE=RELEASE

OPENCORE_UDK_BUILD_DIR=src/OpenCorePkg/UDK/Build/OpenCorePkg/$(OPENCORE_MODE)_XCODE5/X64

.DUMMY : all very-clean clean dist

# Avoid submodules having their own directories as a dependency by moving that dependency to the top here:
# (avoids rebuilding deps after they touch their directories during build)
all : $(SUBMODULES) $(EFI_FILES)

dist : $(SUBMODULES) OpenCore.dmg.gz OpenCoreEFIFolder.zip OpenCore.iso.gz

# Create OpenCore disk image:

OpenCore.dmg : Makefile $(EFI_FILES)
	rm -f OpenCore.dmg
	hdiutil create -layout GPTSPUD -partitionType EFI -fs "FAT32" -megabytes 150 -volname EFI OpenCore.dmg
	mkdir -p OpenCore-Image
	DEV_NAME=$$(hdiutil attach -nomount -plist OpenCore.dmg | xpath "/plist/dict/array/dict/key[text()='content-hint']/following-sibling::string[1][text()='EFI']/../key[text()='dev-entry']/following-sibling::string[1]/text()" 2> /dev/null) && \
		mount -tmsdos "$$DEV_NAME" OpenCore-Image
	cp -a EFI OpenCore-Image/
	hdiutil detach -force OpenCore-Image

# Not actually an ISO, but useful for making it usable in Proxmox's ISO picker
OpenCore.iso : OpenCore.dmg
	cp $< $@

OpenCoreEFIFolder.zip : Makefile $(EFI_FILES)
	rm -f $@
	zip -r $@ EFI

%.gz : %
	gzip -f --keep $<

# AppleALC:

EFI/OC/Kexts/AppleALC.kext : src/AppleALC/build/Release/AppleALC.kext
	cp -a $< $@

src/AppleALC/build/Release/AppleALC.kext : src/AppleALC src/AppleALC/Lilu.kext
	cd src/AppleALC && xcodebuild -configuration Release

src/AppleALC/Lilu.kext : src/Lilu/build/Debug/Lilu.kext
	ln -s ../Lilu/build/Debug/Lilu.kext $@

# Lilu:

EFI/OC/Kexts/Lilu.kext : src/Lilu/build/Release/Lilu.kext
	cp -a $< $@

src/Lilu/build/Release/Lilu.kext src/Lilu/build/Debug/Lilu.kext :
	cd src/Lilu && xcodebuild -configuration Debug
	cd src/Lilu && xcodebuild -configuration Release

# WhateverGreen:

EFI/OC/Kexts/WhateverGreen.kext : src/WhateverGreen/build/Release/WhateverGreen.kext
	cp -a $< $@

src/WhateverGreen/build/Release/WhateverGreen.kext : src/WhateverGreen src/WhateverGreen/Lilu.kext
	cd src/WhateverGreen && xcodebuild -configuration Release

src/WhateverGreen/Lilu.kext : src/Lilu/build/Debug/Lilu.kext
	ln -s ../Lilu/build/Debug/Lilu.kext $@

# VirtualSMC:

EFI/OC/Kexts/VirtualSMC.kext : src/VirtualSMC/build/Release/VirtualSMC.kext
	cp -a $< $@

src/VirtualSMC/build/Release/VirtualSMC.kext : src/VirtualSMC/Lilu.kext
	cd src/VirtualSMC && xcodebuild -configuration Release

src/VirtualSMC/Lilu.kext : src/Lilu/build/Debug/Lilu.kext
	ln -s ../Lilu/build/Debug/Lilu.kext $@

# OpenCore:

EFI/OC/OpenCore.efi : $(OPENCORE_UDK_BUILD_DIR)/OpenCore.efi
	cp -a $< $@

EFI/OC/Drivers/OpenRuntime.efi : $(OPENCORE_UDK_BUILD_DIR)/OpenRuntime.efi
	mkdir -p EFI/OC/Drivers
	cp -a $< $@

EFI/OC/Drivers/VBoxHfs.efi : $(OPENCORE_UDK_BUILD_DIR)/VBoxHfs.efi
	mkdir -p EFI/OC/Drivers
	cp -a $< $@

EFI/BOOT/BOOTx64.efi : $(OPENCORE_UDK_BUILD_DIR)/BOOTx64.efi
	mkdir -p EFI/BOOT
	cp -a $< $@

$(OPENCORE_UDK_BUILD_DIR)/OpenCore.efi $(OPENCORE_UDK_BUILD_DIR)/OpenRuntime.efi \
$(OPENCORE_UDK_BUILD_DIR)/BOOTx64.efi $(OPENCORE_UDK_BUILD_DIR)/Shell.efi \
$(OPENCORE_UDK_BUILD_DIR)/ResetSystem.efi $(OPENCORE_UDK_BUILD_DIR)/OpenCanopy.efi \
$(OPENCORE_UDK_BUILD_DIR)/VBoxHfs.efi \
 :
	cd src/OpenCorePkg && ARCHS=X64 ./build_oc.tool --skip-package $(OPENCORE_MODE)

# Tools

EFI/OC/Tools/Shell.efi : $(OPENCORE_UDK_BUILD_DIR)/Shell.efi
	mkdir -p EFI/OC/Tools
	cp -a $< $@

EFI/OC/Tools/ResetSystem.efi : $(OPENCORE_UDK_BUILD_DIR)/ResetSystem.efi
	mkdir -p EFI/OC/Tools
	cp -a $< $@

EFI/OC/Drivers/OpenCanopy.efi : $(OPENCORE_UDK_BUILD_DIR)/OpenCanopy.efi
	mkdir -p EFI/OC/Drivers
	cp -a $< $@

EFI/OC/Resources : src/OcBinaryData/Resources
	cp -a $< EFI/OC/

# Fetch submodules:

$(SUBMODULES) :
	git submodule update --init

EFI/BOOT/ EFI/OC/Drivers/ EFI/OC/Tools/ :
	mkdir $@

# Also check out the UDK and its dependencies from scratch again - useful when build errors occur in UDK
very-clean : clean
	rm -rf src/OpenCorePkg/UDK

clean :
	rm -rf OpenCore.dmg OpenCoreEFIFolder.zip OpenCore-Image/ src/Lilu/build src/WhateverGreen/build src/OpenCorePkg/UDK/Build \
		src/AppleALC/build $(KEXTS) $(DRIVERS) $(TOOLS) $(MISC)
