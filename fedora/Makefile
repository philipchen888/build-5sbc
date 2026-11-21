FEDORA_RELEASE = 44
ARCH           = aarch64
MOCK_CONFIG    = fedora-$(FEDORA_RELEASE)-$(ARCH)
IMAGE_NAME     = fedora4sbc.raw
BUILD_DIR      = build
ROOTFS_DIR     = $(BUILD_DIR)/mkosi.extra
PACKAGES       = ../packages
CHIP          := rpi4b
GRUBCFG        = $(PACKAGES)/$(CHIP)_grub.cfg
KERNEL_SRC     = ../kernel/linux-$(CHIP)
KERNEL_MODULE  = $(KERNEL_SRC)/tmp/lib/modules/*

.PHONY: setup_host build_image clean

# Step 1: Install cross-architecture build infrastructure
setup_host:
	@echo "--> Setting up system emulation and package build engines..."
	sudo dnf install -y qemu-user-static mock mkosi arm-image-installer
	sudo systemctl start systemd-binfmt || true
	@if ! groups | grep -q "\bmock\b"; then \
		echo "Adding $$USER to the mock execution group..."; \
		sudo usermod -aG mock $$USER; \
		echo "CRITICAL: Please restart your shell or run 'newgrp mock' then rerun make."; \
		exit 1; \
	fi

# Step 2: Dynamically generate the mkosi blueprint alongside configuration credentials
build_image:
	@echo "--> Generating mkosi.conf configuration for Fedora $(FEDORA_RELEASE)..."
	@mkdir -p $(BUILD_DIR)
	@echo "[Distribution]" > $(BUILD_DIR)/mkosi.conf
	@echo "Distribution=fedora" >> $(BUILD_DIR)/mkosi.conf
	@echo "Release=$(FEDORA_RELEASE)" >> $(BUILD_DIR)/mkosi.conf
	@echo "Architecture=arm64" >> $(BUILD_DIR)/mkosi.conf
	@echo "" >> $(BUILD_DIR)/mkosi.conf
	@echo "[Output]" >> $(BUILD_DIR)/mkosi.conf
	@echo "Format=disk" >> $(BUILD_DIR)/mkosi.conf
	@echo "Output=$(IMAGE_NAME)" >> $(BUILD_DIR)/mkosi.conf
	@echo "" >> $(BUILD_DIR)/mkosi.conf
	@echo "[Content]" >> $(BUILD_DIR)/mkosi.conf
	@echo "Bootable=no" >> $(BUILD_DIR)/mkosi.conf
	@echo "Bootloader=none" >> $(BUILD_DIR)/mkosi.conf
	@echo "PartitionTable=gpt" >> $(BUILD_DIR)/mkosi.conf
	@echo "Hostname=linaro" >> $(BUILD_DIR)/mkosi.conf
	@echo "RootPassword=linaro" >> $(BUILD_DIR)/mkosi.conf
	@echo "DefaultTarget=graphical.target" >> $(BUILD_DIR)/mkosi.conf
	@echo "Repositories=fedora,updates" >> $(BUILD_DIR)/mkosi.conf

	@# Write every individual package to its own distinct line entry to force clean parsing
	@for pkg in bash coreutils dnf5 \
		dracut dosfstools e2fsprogs btrfs-progs systemd systemd-udev \
		openssh-server iproute NetworkManager sudo NetworkManager-wifi \
		initial-setup initial-setup-gui gdm @base-x @gnome-desktop \
		vim-enhanced nano xterm wget curl vsftpd which gcc gcc-c++ make \
		@development-tools iputils bind-utils firefox speedtest-cli \
		alsa-utils pipewire wireplumber pipewire-utils pipewire-alsa pipewire-pulseaudio \
		pavucontrol mpv glmark2 \
		vlc-cli vlc-plugins-base vlc-plugins-video-out vlc-plugins-all \
		linux-firmware wpa_supplicant iw wireless-regdb \
		ffmpeg gstreamer1-plugins-good-extras gstreamer1-libav \
		grub2-editenv grub2-mkconfig grubby \
		bluez; do \
		echo "Packages=$$pkg" >> $(BUILD_DIR)/mkosi.conf; \
	done

	@if [ -d "$(BUILD_DIR)/custom_rpms" ] && [ "$$(ls -A $(BUILD_DIR)/custom_rpms)" ]; then \
		echo "ExtraPackages=$(BUILD_DIR)/custom_rpms/*.rpm" >> $(BUILD_DIR)/mkosi.conf; \
	fi

	@echo "--> Preparing overlay configuration template..."
	@rm -rf $(ROOTFS_DIR)
	@mkdir -p $(ROOTFS_DIR)/etc/systemd/system/display-manager.service.wants
	@mkdir -p $(ROOTFS_DIR)/etc/systemd/system/graphical.target.wants
	@mkdir -p $(ROOTFS_DIR)/etc/systemd/system/multi-user.target.wants
	@mkdir -p $(ROOTFS_DIR)/etc/vsftpd
	@mkdir -p $(ROOTFS_DIR)/lib/modules
	@mkdir -p $(ROOTFS_DIR)/lib/firmware/brcm
	@mkdir -p $(ROOTFS_DIR)/lib/firmware/rtl_bt
	@mkdir -p $(ROOTFS_DIR)/lib/firmware/arm/mali/arch10.8
	@mkdir -p $(ROOTFS_DIR)/etc/modules-load.d
	
	@# Inject custom binaries and hardware firmware into overlay target paths
	@cp -r $(KERNEL_MODULE) $(ROOTFS_DIR)/lib/modules
	@cp $(PACKAGES)/mali_csffw.bin $(ROOTFS_DIR)/lib/firmware/arm/mali/arch10.8
	@echo "panthor" > $(ROOTFS_DIR)/etc/modules-load.d/panthor.conf
	@cp $(PACKAGES)/brcmfmac* $(ROOTFS_DIR)/lib/firmware/brcm
	@cp $(PACKAGES)/BCM4345* $(ROOTFS_DIR)/lib/firmware/brcm
	@cp $(PACKAGES)/rtl* $(ROOTFS_DIR)/lib/firmware/rtl_bt
	@echo "UUID=175b850b-d4f3-4214-8c7d-5d34e2b7d4d1  /  btrfs x-systemd.growfs,compress=zstd:1,defaults 0 1" > $(ROOTFS_DIR)/etc/fstab
	@echo "UUID=B30A-A68A /boot/efi vfat    umask=0077  0 1" >> $(ROOTFS_DIR)/etc/fstab

	@# Link GDM & Initial Setup Wizard for the Display interface
	@ln -sf /usr/lib/systemd/system/gdm.service $(ROOTFS_DIR)/etc/systemd/system/display-manager.service
	@ln -sf /usr/lib/systemd/system/initial-setup.service $(ROOTFS_DIR)/etc/systemd/system/graphical.target.wants/initial-setup.service

	@# Force enable SSH and FTP services directly at boot target
	@ln -sf /usr/lib/systemd/system/sshd.service $(ROOTFS_DIR)/etc/systemd/system/multi-user.target.wants/sshd.service
	@ln -sf /usr/lib/systemd/system/vsftpd.service $(ROOTFS_DIR)/etc/systemd/system/multi-user.target.wants/vsftpd.service

	@# Provision vsftpd configuration profile
	@echo "anonymous_enable=NO" > $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "local_enable=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "write_enable=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "local_umask=022" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "dirmessage_enable=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "xferlog_enable=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "connect_from_port_20=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "xferlog_std_format=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "listen=NO" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "listen_ipv6=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "pam_service_name=vsftpd" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf
	@echo "userlist_enable=YES" >> $(ROOTFS_DIR)/etc/vsftpd/vsftpd.conf

	@echo "--> Executing native mkosi build lifecycle..."
	sudo mkosi -C $(BUILD_DIR) build
	@echo "--> Success! System image building loops complete."

clean:
	sudo rm -rf $(BUILD_DIR)
