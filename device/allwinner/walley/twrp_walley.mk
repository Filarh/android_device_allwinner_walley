# El makefile del device y el de dependencias DEBEN llevar prefijo twrp_.
#
# NO heredar de $(SRC_TARGET_DIR)/product/embedded.mk: no existe en el
# manifiesto de TWRP 12.1 (AOSP lo elimino) y el build muere con
#   base_vendor.mk:83: error: "build/make/target/product/embedded.mk" does not exist
#
# Tampoco core_64_bit.mk: esta placa tiene userspace de 32 bits.

$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# El device
$(call inherit-product, device/allwinner/walley/device.mk)

# Lo comun de TWRP
$(call inherit-product-if-exists, vendor/twrp/config/common.mk)

PRODUCT_RELEASE_NAME := walley
PRODUCT_DEVICE := walley
PRODUCT_NAME := twrp_walley
PRODUCT_BRAND := Allwinner
PRODUCT_MODEL := ATV-X3PLUS
PRODUCT_MANUFACTURER := allwinner
