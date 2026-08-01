# BoardConfig para la ATV-X3PLUS (Allwinner H616, sun50iw9p1).
#
# TODOS los valores de abajo salieron de leer el recovery de fabrica y la
# metadata liblp del propio super, no de una plantilla. Ver docs/14-nice_to_have.md.

DEVICE_PATH := device/allwinner/walley

# --- Plataforma -------------------------------------------------------------
# Kernel de 64 bits, userspace de 32. VERIFICADO desmontando el ramdisk del
# recovery de fabrica: init, linker, recovery, sh y toybox son TODOS ELF32 ARM
# y no existe /system/lib64. Poner arm64 aca produce un TWRP que no corre.
TARGET_ARCH := arm
# armv8-a, no armv7-a-neon: el Cortex-A53 ES ARMv8-A, solo que ejecutando
# codigo de 32 bits (AArch32). El build de TWRP rechaza armv7-a-neon con
#   TARGET_linux-arm.mk:53: Incorrect TARGET_ARCH_VARIANT. Use armv8-a instead.
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_SMP := true
# El binder si es de 64 bits: es el esquema "a64" (userspace 32 sobre kernel 64),
# el mismo que usa el GSI de phh que corre en esta caja.
TARGET_USES_64_BIT_BINDER := true
TARGET_BOARD_PLATFORM := cupid
TARGET_BOOTLOADER_BOARD_NAME := sun50iw9p1
TARGET_BOARD_SUFFIX := _64
TARGET_KERNEL_ARCH := arm64

# --- Boot image -------------------------------------------------------------
# OJO: esta placa NO usa los offsets por defecto de mkbootimg.
#   default:  kernel=0x00008000  ramdisk=0x01000000  page_size=4096
#   esta:     kernel=0x00080000  ramdisk=0x03000000  page_size=2048
# Un arbol generico produce una imagen que no arranca.
BOARD_KERNEL_BASE            := 0x40000000
BOARD_KERNEL_PAGESIZE        := 2048
BOARD_KERNEL_OFFSET          := 0x00080000
BOARD_RAMDISK_OFFSET         := 0x03000000
BOARD_KERNEL_SECOND_OFFSET   := 0x00f00000
BOARD_KERNEL_TAGS_OFFSET     := 0x00000100
BOARD_DTB_OFFSET             := 0x04000000
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_MKBOOTIMG_ARGS += --base $(BOARD_KERNEL_BASE)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --second_offset $(BOARD_KERNEL_SECOND_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_KERNEL_CMDLINE := selinux=1 androidboot.selinux=permissive androidboot.dtbo_idx=0,1,2 buildvariant=eng

# Kernel prebuilt sacado del recovery de fabrica (18651144 bytes, sin comprimir)
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
# El DTB va como DIRECTORIO con archivos .dtb, no como una imagen suelta: el
# build concatena *.dtb para armar dtb.img. Con TARGET_PREBUILT_DTB (que no es
# una variable real de AOSP) ninja falla con
#   'out/target/product/walley/dtb.img' missing and no known rule to make it
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb
BOARD_INCLUDE_DTB_IN_BOOTIMG := true

# --- Particiones ------------------------------------------------------------
# recovery es particion DEDICADA (mmcblk0p6, 32 MB), no un ramdisk dentro de boot.
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_HAS_LARGE_FILESYSTEM := true
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_SUPPRESS_SECURE_ERASE := true

# --- super: valores leidos de la metadata liblp real ------------------------
# El grupo se llama 'sb', NO '<algo>_dynamic_partitions'. Y son TRES particiones,
# sin odm. Cualquier plantilla copiada de otro equipo se equivoca en las dos cosas.
BOARD_SUPER_PARTITION_SIZE   := 2147483648
BOARD_SUPER_PARTITION_GROUPS := sb
BOARD_SB_SIZE                := 2139095040
BOARD_SB_PARTITION_LIST      := system vendor product
TARGET_USES_LOGICAL_PARTITIONS := true

# vendor ES una particion propia (logica, dentro de super). Hay que decirlo:
# sin esto AOSP asume que vive dentro de system y crea root/vendor como SYMLINK.
# Pero el HAL de salud instala su manifiesto VINTF en
# recovery/root/vendor/etc/vintf/manifest/, creando ahi un DIRECTORIO real, y
# el rsync que arma el ramdisk muere con
#   could not make way for new symlink: root/vendor
#   cannot delete non-empty directory: root/vendor
# Declarandolo, root/vendor pasa a ser punto de montaje y no hay conflicto.
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# --- AVB --------------------------------------------------------------------
# NO declarar avb= en el fstab: el u-boot de esta caja no pasa
# androidboot.vbmeta.{size,hash_alg,digest}, asi que AvbHandle::Open() falla.
# Ver docs/05-causa-raiz.md y docs/14-nice_to_have.md seccion 4.
BOARD_AVB_ENABLE := false

# --- TWRP -------------------------------------------------------------------
TW_THEME := landscape_hdpi
TW_HAVE_SELINUX := true
TARGET_SCREEN_WIDTH  := 1280
TARGET_SCREEN_HEIGHT := 720
BOARD_HAS_NO_REAL_SDCARD := true
RECOVERY_SDCARD_ON_DATA := true
TW_INCLUDE_REPACKTOOLS := true
TW_EXCLUDE_MTP := true
TW_NO_SCREEN_TIMEOUT := true
TW_NO_USB_STORAGE := true
TW_INPUT_BLACKLIST := "hbtp_vm"
TW_EXTRA_LANGUAGES := false
TW_DEFAULT_BRIGHTNESS := 255
TW_USE_TOOLBOX := true
