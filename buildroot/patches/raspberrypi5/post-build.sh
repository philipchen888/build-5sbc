#!/bin/sh

set -u
set -e

BOARD_DIR="$(dirname $0)"
KERNEL_DIR="${BOARD_DIR}/../../../../kernel/linux-rpi5"

# Add a console on tty1
if [ -e ${TARGET_DIR}/etc/inittab ]; then
    sed -i '/tty1.*GENERIC_SERIAL/s/^/# /' ${TARGET_DIR}/etc/inittab
    grep -qE '^tty1::' ${TARGET_DIR}/etc/inittab || \
        sed -i '/GENERIC_SERIAL/a\
tty1::respawn:/sbin/getty -L  tty1 0 vt100 # HDMI console' ${TARGET_DIR}/etc/inittab
# systemd doesn't use /etc/inittab, enable getty.tty1.service instead
elif [ -d ${TARGET_DIR}/etc/systemd ]; then
    mkdir -p "${TARGET_DIR}/etc/systemd/system/getty.target.wants"
    ln -sf /lib/systemd/system/getty@.service \
       "${TARGET_DIR}/etc/systemd/system/getty.target.wants/getty@tty1.service"
fi

mkdir -p "${BINARIES_DIR}/efi-part/EFI/BOOT"
cp "${BOARD_DIR}/grub.cfg" "${BINARIES_DIR}/efi-part/EFI/BOOT/grub.cfg"
install -m 0644 -D ${KERNEL_DIR}/arch/arm64/boot/Image $BINARIES_DIR/Image
install -m 0644 -D ${KERNEL_DIR}/arch/arm64/boot/dts/broadcom/bcm2712-rpi-5-b.dtb $BINARIES_DIR/bcm2712-rpi-5-b.dtb

CUSTOM_MOD_DIR="${KERNEL_DIR}/tmp/lib/modules"

if [ -d "${CUSTOM_MOD_DIR}" ]; then
    rm -rf "${TARGET_DIR}/lib/modules"
    mkdir -p "${TARGET_DIR}/lib/modules"
    cp -a "${CUSTOM_MOD_DIR}/." "${TARGET_DIR}/lib/modules/"
fi
