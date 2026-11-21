#!/bin/sh
set -e

BOARD_DIR="$(dirname "$0")"
INITRAMFS_OVERLAY="${BOARD_DIR}/initramfs-overlay"
TMP_CPIO_DIR="${BINARIES_DIR}/initramfs-tmp"
FAKEROOT="${HOST_DIR}/bin/fakeroot"

echo ">>> Running post-image.sh: injecting ${INITRAMFS_OVERLAY} into ${BINARIES_DIR}/rootfs.cpio.gz"

"${FAKEROOT}" -- /bin/sh -c '
    set -e
    rm -rf "'"${TMP_CPIO_DIR}"'"
    mkdir -p "'"${TMP_CPIO_DIR}"'"

    gzip -dc "'"${BINARIES_DIR}/rootfs.cpio.gz"'" | (cd "'"${TMP_CPIO_DIR}"'" && cpio -idmu --quiet)

    rm -f "'"${TMP_CPIO_DIR}/init"'"
    cp -a "'"${INITRAMFS_OVERLAY}/."'" "'"${TMP_CPIO_DIR}/"'"
    chmod 0755 "'"${TMP_CPIO_DIR}/init"'"

    (cd "'"${TMP_CPIO_DIR}"'" && find . | cpio -o -H newc --quiet | gzip -9 > "'"${BINARIES_DIR}/rootfs.cpio.gz"'")
    rm -rf "'"${TMP_CPIO_DIR}"'"
'
