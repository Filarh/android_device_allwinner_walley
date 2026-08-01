LOCAL_PATH := device/allwinner/walley

# Control remoto infrarrojo: binario y keylayouts sacados del recovery de fabrica.
# El binario va como modulo de Soong (ver Android.bp): PRODUCT_COPY_FILES
# rechaza los ELF. El .rc es texto y si puede ir por copia.
TARGET_RECOVERY_DEVICE_MODULES += multi_ir
PRODUCT_PACKAGES += multi_ir

# lptools: rehace el mapeo dm-linear de las particiones logicas con
# force_writable=true. Sin el no se puede escribir en system/vendor/product,
# porque en los metadatos de super estan marcadas READONLY y TWRP las mapea
# tal cual (llama a CreateLogicalPartitions con force_writable=false).
# El repo lo clona el workflow en vendor/lptools.
TARGET_RECOVERY_DEVICE_MODULES += lptools
PRODUCT_PACKAGES += lptools

# El .rc va a la RAIZ del ramdisk como init.recovery.<ro.hardware>.rc, que es
# el nombre que init carga solo -- igual que el recovery de fabrica. El build
# de AOSP preserva los init.recovery.*.rc de la raiz y BORRA cualquier otro
# init*.rc, asi que ponerlo en /system/etc/init/ no habria funcionado.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.sun50iw9p1.rc:recovery/root/init.recovery.sun50iw9p1.rc

PRODUCT_COPY_FILES += $(foreach f,$(wildcard $(LOCAL_PATH)/recovery/root/system/usr/keylayout/*.kl),\
    $(f):recovery/root/system/usr/keylayout/$(notdir $(f)))

# El fstab NO se copia aca: se declara con TARGET_RECOVERY_FSTAB en el
# BoardConfig. Hacer las dos cosas genera una regla de instalacion duplicada.

# Sin bootctrl ni el HAL de boot: esta caja NO es A/B. Tiene particiones
# boot y recovery dedicadas y un solo slot.
