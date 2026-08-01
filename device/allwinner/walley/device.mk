LOCAL_PATH := device/allwinner/walley

# Control remoto infrarrojo: binario y keylayouts sacados del recovery de fabrica.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/bin/multi_ir:recovery/root/system/bin/multi_ir \
    $(LOCAL_PATH)/recovery/root/system/etc/init/multi_ir.rc:recovery/root/system/etc/init/multi_ir.rc

PRODUCT_COPY_FILES += $(foreach f,$(wildcard $(LOCAL_PATH)/recovery/root/system/usr/keylayout/*.kl),\
    $(f):recovery/root/system/usr/keylayout/$(notdir $(f)))

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery.fstab:recovery/root/system/etc/recovery.fstab

PRODUCT_PACKAGES += \
    bootctrl \
    android.hardware.boot@1.0-impl \
    android.hardware.boot@1.0-service
