.ONESHELL:
SHELL := /bin/bash

# --- Configuration Variables ---
TARGET_ARCH      := arm64
CROSS_COMPILE    := aarch64-linux-gnu-
SUITE            := trixie
MIRROR           := http://ftp.us.debian.org/debian
BUILD_DIR        := build
ROOTFS_DIR       := $(BUILD_DIR)/rootfs-debian
PACKAGES         := ../packages
CHIP             := rockpi4b
GRUBCFG = $(PACKAGES)/$(CHIP)_grub.cfg
KERNEL_SRC = ../kernel/linux-$(CHIP)

ifeq ($(SUITE),bookworm)
	CHROOT_PACKAGES = policykit-1 openssh-server network-manager bluez chrony build-essential git v4l-utils grub-efi-arm64 zstd initramfs-tools gdm3 grub-common task-gnome-desktop xterm vsftpd gcc g++ make git iputils-ping bind9-dnsutils alsa-utils pipewire wireplumber pipewire-audio pavucontrol mpv glmark2 vlc firmware-linux iw wireless-regdb ffmpeg gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav
else
	CHROOT_PACKAGES = openssh-server network-manager bluez chrony build-essential git v4l-utils grub-efi-arm64 zstd initramfs-tools gdm3 grub-common task-gnome-desktop xterm vsftpd gcc g++ make git iputils-ping bind9-dnsutils alsa-utils pipewire wireplumber pipewire-audio pavucontrol mpv glmark2 vlc firmware-linux iw wireless-regdb ffmpeg gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-libav
endif

# Default user profile
USER_NAME        := linaro
USER_PASS        := linaro
USER_UID         := 1000

# Cleaned package array configuration
BASE_PACKAGES := bash,coreutils,dosfstools,e2fsprogs,btrfs-progs,systemd,systemd-sysv,udev,dbus,iproute2,sudo,vim,nano,wget,curl,ca-certificates,locales,kmod

.PHONY: all clean rootfs_base finalize

all: rootfs_base finalize

# --- 2. Build Base Rootfs ---
rootfs_base:
	@echo "Building Debian base file structure with debootstrap..."
	mkdir -p $(ROOTFS_DIR)
	sudo debootstrap \
		--arch=$(TARGET_ARCH) \
		--include=$(BASE_PACKAGES) \
		--components="main,non-free-firmware" \
		$(SUITE) \
		$(ROOTFS_DIR) \
		$(MIRROR)

# --- 3. Finalize & Install Components ---
finalize:
	set -e -E
	@echo "Installing compiled vendor kernel and modules into rootfs..."
	sudo mkdir -p $(ROOTFS_DIR)/lib/modules
	sudo cp -r $(KERNEL_SRC)/tmp/lib/modules/* $(ROOTFS_DIR)/lib/modules/	
	# Create traditional EFI storage layouts
	sudo mkdir -p $(ROOTFS_DIR)/boot/efi
	sudo mkdir -p $(ROOTFS_DIR)/boot/firmware
	sudo mkdir -p $(ROOTFS_DIR)/boot/grub
	sudo cp -r $(KERNEL_SRC)/tmp/boot/* $(ROOTFS_DIR)/boot/
	sudo mkdir -p $(ROOTFS_DIR)/lib/firmware/brcm
	sudo mkdir -p $(ROOTFS_DIR)/lib/firmware/rtl_bt
	sudo mkdir -p $(ROOTFS_DIR)/lib/firmware/arm/mali/arch10.8
	sudo mkdir -p $(ROOTFS_DIR)/etc/modules-load.d
	sudo cp $(PACKAGES)/mali_csffw.bin $(ROOTFS_DIR)/lib/firmware/arm/mali/arch10.8
	echo "panthor" | sudo tee $(ROOTFS_DIR)/etc/modules-load.d/panthor.conf
	sudo cp $(PACKAGES)/brcmfmac* $(ROOTFS_DIR)/lib/firmware/brcm
	sudo cp $(PACKAGES)/BCM4345* $(ROOTFS_DIR)/lib/firmware/brcm
	sudo cp $(PACKAGES)/rtl* $(ROOTFS_DIR)/lib/firmware/rtl_bt

	KERNEL_VERSION=$$(ls $(ROOTFS_DIR)/boot/vmlinuz-* 2>/dev/null | sed 's|.*/vmlinuz-||' | sort -V | tail -n 1); \
	sudo sed -e "s/6.18.0/$$KERNEL_VERSION/g" < $(GRUBCFG) | sudo tee $(ROOTFS_DIR)/boot/grub/grub.cfg > /dev/null
	@echo "Configuring network identity and standard partitions..."
	echo "linaro-alip" | sudo tee $(ROOTFS_DIR)/etc/hostname > /dev/null
	echo "127.0.0.1   localhost linaro-alip" | sudo tee $(ROOTFS_DIR)/etc/hosts > /dev/null
	

	# 1. Define the Bash function and trap at the start of the recipe
	finish() { \
		echo "An error occurred! Cleaning up mounts..."; \
		sudo umount -lf $(ROOTFS_DIR)/proc || true; \
		sudo umount -lf $(ROOTFS_DIR)/sys || true; \
		sudo umount -lf $(ROOTFS_DIR)/dev/pts || true; \
		sudo umount -lf $(ROOTFS_DIR)/dev || true; \
		sync; \
		exit 255; \
	}
	trap finish ERR
	sudo cp /usr/bin/qemu-aarch64-static $(ROOTFS_DIR)/usr/bin/
	@echo "Mounting kernel virtual filesystems and mirroring EFI target mappings for chroot..."
	sudo mount -o bind /dev $(ROOTFS_DIR)/dev
	sudo mount -o bind /dev/pts $(ROOTFS_DIR)/dev/pts
	sudo mount -o bind /sys $(ROOTFS_DIR)/sys
	sudo mount -o bind /proc $(ROOTFS_DIR)/proc

	@echo "Disable update-grub"
	-sudo chroot $(ROOTFS_DIR) dpkg-divert --local --rename --add /usr/sbin/update-grub
	sudo ln -sf /bin/true $(ROOTFS_DIR)/usr/sbin/update-grub

	@echo "Executing software setups inside the environment..."
	sudo rm -rf $(ROOTFS_DIR)/etc/resolv.conf
	echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" | sudo tee $(ROOTFS_DIR)/etc/resolv.conf
	sudo resolvconf -u
	sudo chroot $(ROOTFS_DIR) apt-get update

	# 3. WORKAROUND FOR EXIT STATUS 73: Temporarily mask systemd-tmpfiles
	@echo "Applying systemd-tmpfiles bypass for Debian Forky..."
	-sudo mv $(ROOTFS_DIR)/usr/bin/systemd-tmpfiles $(ROOTFS_DIR)/usr/bin/systemd-tmpfiles.bak
	-sudo ln -s /bin/true $(ROOTFS_DIR)/usr/bin/systemd-tmpfiles

	# 4. Force-configure systemd and fix broken packages
	-sudo chroot $(ROOTFS_DIR) apt-get install -y systemd systemd-sysv libpam-systemd
	-sudo chroot $(ROOTFS_DIR) apt-get install -f -y

	sudo DEBIAN_FRONTEND=noninteractive chroot $(ROOTFS_DIR) apt-get install -y $(CHROOT_PACKAGES)
ifeq ($(SUITE),bookworm)
	sudo chroot $(ROOTFS_DIR) /bin/bash -c '\
		export DEBIAN_FRONTEND=noninteractive && \
		echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/backports.list && \
		apt-get update && \
		apt-get install -t bookworm-backports -y --no-install-recommends \
			mesa-vulkan-drivers mesa-va-drivers libgl1-mesa-dri libglx-mesa0 libegl-mesa0 libgbm1 libgles2-mesa && \
		ldconfig \
	'
endif
	# 6. RESTORE systemd-tmpfiles after installation finishes
	@echo "Restoring systemd-tmpfiles..."
	-sudo rm $(ROOTFS_DIR)/usr/bin/systemd-tmpfiles
	-sudo mv $(ROOTFS_DIR)/usr/bin/systemd-tmpfiles.bak $(ROOTFS_DIR)/usr/bin/systemd-tmpfiles
	sudo chroot $(ROOTFS_DIR) apt-get purge flash-kernel -y
	echo "UUID=b921b045-1df0-41c3-af44-4c6f280d3fae /  ext4    errors=remount-ro   0   1" | sudo tee $(ROOTFS_DIR)/etc/fstab > /dev/null
ifeq ($(CHIP),$(filter $(CHIP),rpi4b rpi5))
	echo "UUID=95E4-6EA5  /boot/firmware  vfat    umask=0077      0       1" | sudo tee -a $(ROOTFS_DIR)/etc/fstab > /dev/null
else
	echo "UUID=95E4-6EA5  /boot/efi  vfat    umask=0077      0       1" | sudo tee -a $(ROOTFS_DIR)/etc/fstab > /dev/null
endif
	@echo "Configuring local user accounts & shell settings..."
	if ! sudo chroot $(ROOTFS_DIR) id -u $(USER_NAME) >/dev/null 2>&1; then \
		sudo chroot $(ROOTFS_DIR) useradd -d /home/$(USER_NAME) -G adm,sudo,video,audio,plugdev -m -N -u $(USER_UID) -s /bin/bash $(USER_NAME); \
	fi
	echo "$(USER_NAME):$(USER_PASS)" | sudo chroot $(ROOTFS_DIR) chpasswd
	echo "root:$(USER_PASS)" | sudo chroot $(ROOTFS_DIR) chpasswd

	@echo "Generating System Initramfs mappings..."
	-sudo chroot $(ROOTFS_DIR) update-initramfs -c -k all
	sudo chroot $(ROOTFS_DIR) apt-get update
	sudo chroot $(ROOTFS_DIR) apt-get upgrade

	@echo "Cleaning apt caching footprint..."
	sudo rm -rf $(ROOTFS_DIR)/var/lib/apt/lists/*
	sync

	@echo "Safely cleaning up mounted virtual filesystems..."
	sudo umount -lf $(ROOTFS_DIR)/proc || true
	sudo umount -lf $(ROOTFS_DIR)/sys || true
	sudo umount -lf $(ROOTFS_DIR)/dev/pts || true
	sudo umount -lf $(ROOTFS_DIR)/dev || true
	sync

# --- Clean-up Rules ---
clean:
	@echo "Cleaning up local workspace directories..."
	if [ -d "$(ROOTFS_DIR)" ]; then sudo rm -rf $(ROOTFS_DIR); fi
