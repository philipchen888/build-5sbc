#!/bin/sh -e

BOOT=/dev/sda
ROOTFS_UUID="b921b045-1df0-41c3-af44-4c6f280d3fae"
umount ${BOOT}* 2>/dev/null || true

echo "🧹 Clearing the partition table area..."
dd if=/dev/zero of="${BOOT}" bs=1M count=34 conv=notrunc,fsync

echo "📐 Creating GPT layout and partitions..."
parted -s "${BOOT}" mklabel gpt

# Partition 1: ESP (FAT32) -> Sector 34816 to 1058815 (512MB)
parted -s "${BOOT}" unit s mkpart esp fat32 32768 1081343
parted -s "${BOOT}" set 1 boot on

# Partition 2: ROOTFS (ext4) -> Sector 5154816 to end of disk (-34 sectors)
parted -s "${BOOT}" -- unit s mkpart rootfs ext4 1081344 -34s

echo "🆔 Setting explicit Partition UUIDs via sgdisk..."
# Using sgdisk is cleaner and non-interactive compared to gdisk EOF blocks
sgdisk -u 2:"${ROOTFS_UUID}" "${BOOT}"

echo "💾 Flashing images directly to target sectors..."

# Flash Partition 1 (ESP) -> Sector 34816 (34816 * 512 = 17825792 bytes -> 4352 * 4096)
echo "Writing ESP Image..."
dd if=./linaro-esp.img of="${BOOT}" bs=4096 seek=4096 conv=notrunc,fsync

# Flash Partition 2 (Rootfs ext4) -> Sector 5154816 (5154816 * 512 = 2639265792 bytes -> 644352 * 4096)
echo "Writing Rootfs Image from internal partition..."

# 2. Flash ONLY the first internal partition (p1) to your target drive sector offset
sudo dd if=./linaro-rootfs.img of="${BOOT}" bs=4096 seek=135168 conv=notrunc,fsync status=progress

# 4. Tune the newly flashed Btrfs filesystem on sda3 to use your exact target UUID
echo "Enforcing target ext4 UUID on Partition 2..."
sudo tune2fs -U "${ROOTFS_UUID}" "${BOOT}2"

echo "🎉 Done! Drive partitioning and writing complete."
