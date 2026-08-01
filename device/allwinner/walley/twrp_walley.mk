# El makefile del device y el de dependencias DEBEN llevar prefijo twrp_.
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)
$(call inherit-product-if-exists, vendor/twrp/config/common.mk)
$(call inherit-product, device/allwinner/walley/device.mk)

PRODUCT_DEVICE := walley
PRODUCT_NAME := twrp_walley
PRODUCT_BRAND := Allwinner
PRODUCT_MODEL := ATV-X3PLUS
PRODUCT_MANUFACTURER := allwinner

PRODUCT_GMS_CLIENTID_BASE := android-allwinner
