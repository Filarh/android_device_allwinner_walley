# TWRP para ATV-X3PLUS (Allwinner H616, sun50iw9p1)

Device tree para una TV box genérica china con SoC Allwinner H616. **No existe TWRP público
para H616**; el precedente más cercano es el X96Q con H313, de la misma familia `sun50iw9`.

Todos los valores de `BoardConfig.mk` salieron de **leer el hardware**, no de una plantilla:
del `recovery.img` de fábrica y de la metadata liblp de la propia partición `super`.

## Los valores que hacen fallar a un device tree genérico

| | Convención habitual | **Esta placa** |
|---|---|---|
| `TARGET_ARCH` | arm64 | **arm** (userspace de 32 bits sobre kernel de 64) |
| kernel offset | `0x00008000` | **`0x00080000`** |
| ramdisk offset | `0x01000000` | **`0x03000000`** |
| page size | 4096 | **2048** |
| grupo de `super` | `<algo>_dynamic_partitions` | **`sb`** |
| particiones lógicas | system vendor product odm | **system vendor product** (sin odm) |

El offset del kernel es **diez veces** el default. Con la plantilla genérica sale una imagen
que sencillamente no arranca, y el síntoma es una pantalla de "androide caído" sin más pista.

La arquitectura se verificó desmontando el ramdisk del recovery de fábrica: `init`, `linker`,
`recovery`, `sh` y `toybox` son **todos ELF32 ARM**, y no existe `/system/lib64`.

## El control remoto infrarrojo funciona

El recovery de fábrica ya maneja el mando, y su cadena está incluida acá en
`recovery/root/system/`. Es una versión **distinta y mejor** que la de `/system`:

| | `/system/bin/multi_ir` | **recovery** |
|---|---|---|
| Tamaño | 34740 bytes | **20332 bytes** |
| Librerías | + `libbinder`, `libandroid_runtime`, `libmultiirservice.so` | solo las siete estándar |
| `sunxi-ir.kl` | 4411 bytes, 13 etiquetas que Android 11 rechaza | **274 bytes, 19 teclas, ninguna inválida** |

La versión del recovery no usa binder. Las siete librerías que pide ya están en cualquier
ramdisk de TWRP.

> **Ojo con el `seclabel`**: el original es `u:r:multi_ir:s0`, un dominio que solo existe en la
> política de fábrica. Acá se usa `u:r:recovery:s0`.

## No declarar `avb=` en el fstab

El u-boot de esta caja **no pasa** `androidboot.vbmeta.{size,hash_alg,digest}`, así que
`AvbHandle::Open()` llama a `AvbVerifier::Create()`, no encuentra esos valores y devuelve
`nullptr`. Además el flag `avb` en cualquier entrada activa `need_dm_verity_`, que obliga a init
a esperar las seis particiones que declara el device tree en `vbmeta/parts`.

## Cómo compilar

No hace falta una máquina local: `Actions` → `Compilar TWRP` → `Run workflow`.

El workflow libera espacio en el runner (los de Ubuntu traen solo ~25 GB libres de 72),
sincroniza el manifiesto mínimo `twrp-12.1`, coloca este árbol y compila.

## Instalar

`recovery` es una **partición dedicada** (`mmcblk0p6`, 32 MB), no un ramdisk dentro de `boot`.
Si la imagen sale mal, el arranque normal queda intacto.

```
adb push recovery.img /sdcard/Download/twrp.img
su 0 dd if=/sdcard/Download/twrp.img of=/dev/block/by-name/recovery bs=1M
su 0 sync
su 0 setprop sys.powerctl reboot,recovery
```

Hacer respaldo del recovery de fábrica **antes**:

```
su 0 dd if=/dev/block/by-name/recovery of=/sdcard/recovery-stock.img
```
