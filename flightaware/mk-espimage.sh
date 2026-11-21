#!/bin/bash -e

BOOTIMAGE="linaro-esp.img"
BOOT_UUID=95E46EA5
CHIP=${CHIP:-rockpi4b}
EFI_DIR="../packages/trixie"
TMP_FW_DIR="./rpi_fw_tmp"

if [ "$CHIP" == "rpi4b" ]; then
	ZIP_PATH="~/Downloads/RPi4_UEFI_Firmware.zip"
elif [ "$CHIP" == "rpi5" ]; then
	ZIP_PATH="~/Downloads/RPi5_UEFI_Release.zip"
fi

if [ -e ${BOOTIMAGE} ]; then
	rm ${BOOTIMAGE}
fi

echo Format boot to vfat
mkfs.vfat -n "boot" -i ${BOOT_UUID} -S 512 -C ${BOOTIMAGE} 512000

mmd -i ${BOOTIMAGE} ::/EFI
mmd -i ${BOOTIMAGE} ::/EFI/boot
mmd -i ${BOOTIMAGE} ::/EFI/debian
mcopy -i ${BOOTIMAGE} -s ${EFI_DIR}/grubaa64.efi ::/EFI/boot/bootaa64.efi
mcopy -i ${BOOTIMAGE} -s ${EFI_DIR}/grubaa64.efi ::/EFI/debian
mcopy -i ${BOOTIMAGE} -s ${EFI_DIR}/grub.cfg ::/EFI/debian

# Clean up any old temporary firmware directory
if [ -d ${TMP_FW_DIR} ]; then
        rm -rf ${TMP_FW_DIR}
fi

if [[ "$CHIP" == "rpi4b" || "$CHIP" == "rpi5" ]] then
	echo "Extracting Raspberry Pi UEFI Firmware..."
	mkdir -p ${TMP_FW_DIR}
	7z x "$(eval echo ${ZIP_PATH})" -o${TMP_FW_DIR}

	echo "Injecting RPi Firmware into ESP..."
	mcopy -i ${BOOTIMAGE} -s ${TMP_FW_DIR}/* ::/

	rm -rf ${TMP_FW_DIR}
fi

echo Boot Image: ${BOOTIMAGE}
