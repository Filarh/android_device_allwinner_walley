LOCAL_PATH := device/allwinner/walley

# Control remoto infrarrojo: binario y keylayouts sacados del recovery de fabrica.
# El binario va como modulo de Soong (ver Android.bp): PRODUCT_COPY_FILES
# rechaza los ELF. El .rc es texto y si puede ir por copia.
TARGET_RECOVERY_DEVICE_MODULES += multi_ir
PRODUCT_PACKAGES += multi_ir

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/init/multi_ir.rc:recovery/root/system/etc/init/multi_ir.rc

PRODUCT_COPY_FILES += $(foreach f,$(wildcard $(LOCAL_PATH)/recovery/root/system/usr/keylayout/*.kl),\
    $(f):recovery/root/system/usr/keylayout/$(notdir $(f)))

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery.fstab:recovery/root/system/etc/recovery.fstab

# Sin bootctrl ni el HAL de boot: esta caja NO es A/B. Tiene particiones
# boot y recovery dedicadas y un solo slot.
