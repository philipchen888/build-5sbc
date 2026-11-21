#!/bin/sh -e

BOOT=/dev/sda
IMAGE="./build/fedora4sbc.raw.raw"
MOUNT_DIR="./build/fedora_root"
ROOTFS_UUID="175b850b-d4f3-4214-8c7d-5d34e2b7d4d1"
CHIP="${CHIP:-rpi4b}"
GRUBCFG="./packages/${CHIP}_grub.cfg"
KERNEL_SRC="../kernel/linux-${CHIP}"
echo $CHIP $GRUBCFG $KERNEL_SRC

# 1. Check if the image file exists
if [ ! -f "$IMAGE" ]; then
    echo "Error: $IMAGE not found in the current directory."
    exit 1
fi

# 2. Create the mount directory if it doesn't exist
if [ ! -d "$MOUNT_DIR" ]; then
    echo "Creating mount directory: $MOUNT_DIR"
    mkdir "$MOUNT_DIR"
fi

umount ${BOOT}* 2>/dev/null || true

echo "🧹 Clearing the partition table area..."
dd if=/dev/zero of="${BOOT}" bs=1M count=34 conv=notrunc,fsync

echo "📐 Creating GPT layout and partitions..."
parted -s "${BOOT}" mklabel gpt

# Partition 1: ESP (FAT32) -> Sector 34816 to 1058815 (512MB)
parted -s "${BOOT}" unit s mkpart esp fat32 34816 1058815
parted -s "${BOOT}" set 1 boot on

# Partition 2: ROOTFS (BTRFS) -> Sector 1058816 to end of disk (-34 sectors)
parted -s "${BOOT}" -- unit s mkpart rootfs btrfs 1058816 -34s

echo "🆔 Setting explicit Partition UUIDs via sgdisk..."
sgdisk -u 2:"${ROOTFS_UUID}" "${BOOT}"

echo "Writing ESP Image..."
dd if=./fedora-esp.img of="${BOOT}" bs=4096 seek=4352 conv=notrunc,fsync

echo "Attaching image to loop device..."
# 3. Attach image and capture the loop device name (e.g., /dev/loop0)
LOOP_DEV=$(sudo losetup -P -f --show "$IMAGE")
echo "Image attached to $LOOP_DEV"

# 2. Flash ONLY the first internal partition (p1) to your target drive sector offset
sudo dd if="${LOOP_DEV}p1" of="${BOOT}" bs=4096 seek=132352 conv=notrunc,fsync status=progress

# 3. Clean up and detach the loop device immediately
sudo losetup -d "${LOOP_DEV}"

# 4. Tune the newly flashed Btrfs filesystem on sda2 to use your exact target UUID
echo "Enforcing target Btrfs UUID on Partition 2..."
sudo btrfstune -M "${ROOTFS_UUID}" "${BOOT}2"

# Define your cleanup function
finish() {
    # Disable the trap immediately so it doesn't loop infinitely if a cleanup command itself fails
    trap - ERR EXIT
    
    echo "⚠️ An error occurred! Cleaning up system virtual mounts safely..."
    
    # -l (lazy) and -f (force) unmount ensures loops break even if files are currently busy
    sudo umount -lf "${MOUNT_DIR}/proc" 2>/dev/null || true
    sudo umount -lf "${MOUNT_DIR}/sys" 2>/dev/null || true
    sudo umount -lf "${MOUNT_DIR}/dev/pts" 2>/dev/null || true
    sudo umount -lf "${MOUNT_DIR}/dev" 2>/dev/null || true
    sudo umount -lf "${MOUNT_DIR}" 2>/dev/null || true
    
    # Detach any loop devices if they were left hanging
    if [ -n "$LOOP_DEV" ]; then
        sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi
    
    sync
    echo "🧹 Cleanup complete. Exiting."
    exit 255
}

# Catch any non-zero exit codes (errors) and route them instantly to the finish function
trap finish ERR

sudo mount "${BOOT}2" "${MOUNT_DIR}"
sudo \rm -rf "${MOUNT_DIR}/boot/"*
sudo cp -a "${KERNEL_SRC}/tmp/boot/"* "${MOUNT_DIR}/boot/"
sudo mkdir -p "./build/fedora_root/boot/grub"
KERNEL_VERSION=$(ls ${MOUNT_DIR}/boot/vmlinuz-* 2>/dev/null | sed 's|.*/vmlinuz-||' | sort -V | tail -n 1)
sudo sed -e "s/6.18.0/${KERNEL_VERSION}/g" < "${GRUBCFG}" | sudo tee "${MOUNT_DIR}/boot/grub/grub.cfg" > /dev/null

echo "🔧 Preparing ARM64 chroot environment..."
# 1. Mount virtual system systems required by dracut/initramfs generators
sudo mount --bind /dev "${MOUNT_DIR}/dev"
sudo mount --bind /dev/pts "${MOUNT_DIR}/dev/pts"
sudo mount --bind /sys "${MOUNT_DIR}/sys"
sudo mount --bind /proc "${MOUNT_DIR}/proc"
# 2. Copy the host's QEMU emulator inside the rootfs so ARM binaries can execute
sudo cp /usr/bin/qemu-aarch64-static "${MOUNT_DIR}/usr/bin/"

echo "📦 Generating initrd.img-${KERNEL_VERSION} inside the chroot..."
# 3. Run dracut inside the chroot environment to build the initrd
#    --force overwrites any existing file with that name
sudo chroot "${MOUNT_DIR}" dracut --force --no-hostonly --no-hostonly-cmdline --add "btrfs base kernel-modules" "/boot/initrd.img-${KERNEL_VERSION}" "${KERNEL_VERSION}"

echo "🧹 Cleaning up chroot mounts..."
# 4. Remove the temporary emulator file
sudo rm -f "${MOUNT_DIR}/usr/bin/qemu-aarch64-static"

# 5. Unmount virtual filesystems in strict reverse order
sudo umount -lf "${MOUNT_DIR}/proc" 2>/dev/null || true
sudo umount -lf "${MOUNT_DIR}/sys" 2>/dev/null || true
sudo umount -lf "${MOUNT_DIR}/dev/pts" 2>/dev/null || true
sudo umount -lf "${MOUNT_DIR}/dev" 2>/dev/null || true
sudo umount -lf "${MOUNT_DIR}" 2>/dev/null || true
sync
echo "✅ Initrd successfully generated and placed in /boot!"

echo "🎉 Done! Drive partitioning and writing complete."
