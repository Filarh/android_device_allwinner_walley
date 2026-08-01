#!/usr/bin/env python3
"""Aplica los hooks manuales de syscall que KernelSU necesita en este kernel 4.9.

Por qué a mano y no con `patch`: un .patch se rompe si el árbol mueve una línea
de contexto, y falla a medias. Acá cada hook declara su ancla, se verifica que
aparezca UNA sola vez, y si algo no calza el script aborta sin tocar nada. Es
idempotente: si el hook ya está, lo saltea.

Por qué hacen falta TODOS los hooks (y no solo los de sucompat): el kernel de
esta caja tiene **CONFIG_KPROBES apagado**, así que `CONFIG_KSU_KPROBES_KSUD`
—que por defecto vendría encendido y resolvería ksud por kprobes— queda
deshabilitado. Los hooks de `newfstat` y `sys_reboot`, que en un kernel con
kprobes son opcionales, acá son obligatorios.

Fuente de los parches: backslashxx/KernelSU issue #5 ("scope-minimized manual
hooks v2.2"), eligiendo en cada caso la variante que corresponde a 4.9:
  - execve      -> vía do_execve (variante "3.18+"), + compat para 32 bits
  - faccessat   -> variante "4.14 y anteriores"
  - newfstatat  -> + fstatat64, porque el userspace de esta caja es de 32 bits
  - newfstat    -> ret_hook, + fstat64
  - sys_reboot  -> kernel/reboot.c (variante "3.18+")
  - policy_rwlock -> opcional, aplica a 3.0~4.9

Uso:  aplicar-hooks-ksu.py <raiz del arbol del kernel>
"""

import os
import sys

# Cada entrada: (archivo, etiqueta, ancla, texto, dónde, obligatorio)
#   dónde = 'antes' | 'despues'
# El ancla tiene que aparecer EXACTAMENTE una vez en el archivo (o en el tramo
# de función acotado por 'desde', si se indica).

DECL_EXECVE = """#ifdef CONFIG_KSU
__attribute__((hot))
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,
			void *argv, void *envp, int *flags);
#endif

"""

LLAMADA_EXECVE = """#ifdef CONFIG_KSU
	ksu_handle_execveat((int *)AT_FDCWD, &filename, &argv, &envp, 0);
#endif
"""

DECL_FACCESSAT = """#ifdef CONFIG_KSU
__attribute__((hot))
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
				int *mode, int *flags);
#endif

"""

DECL_STAT = """#ifdef CONFIG_KSU
__attribute__((hot))
extern int ksu_handle_stat(int *dfd, const char __user **filename_user,
				int *flags);
#endif
#if defined(CONFIG_KSU) && !defined(CONFIG_KSU_KPROBES_KSUD)
extern void ksu_handle_newfstat_ret(unsigned int *fd,
				struct stat __user **statbuf_ptr);
extern void ksu_handle_fstat64_ret(unsigned long *fd,
				struct stat64 __user **statbuf_ptr);
#endif

"""

DECL_REBOOT = """#if defined(CONFIG_KSU) && !defined(CONFIG_KSU_KPROBES_KSUD)
extern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd,
				void __user **arg);
#endif

"""

HOOKS = [
    # ---- fs/exec.c -------------------------------------------------------
    ("fs/exec.c", "decl execve",
     "int do_execve(struct filename *filename,\n",
     DECL_EXECVE, "antes", True, None),
    # OJO: los dos llevan 'desde'. Sin acotar la función, el chequeo de "ya
    # aplicado" ve el hook que se acaba de meter en do_execve y saltea compat.
    ("fs/exec.c", "do_execve",
     "\tstruct user_arg_ptr envp = { .ptr.native = __envp };\n"
     "\treturn do_execveat_common(AT_FDCWD, filename, argv, envp, 0);\n",
     LLAMADA_EXECVE, "medio", True, "int do_execve(struct filename *filename,"),
    ("fs/exec.c", "compat_do_execve",
     "\t\t.ptr.compat = __envp,\n\t};\n"
     "\treturn do_execveat_common(AT_FDCWD, filename, argv, envp, 0);\n",
     LLAMADA_EXECVE, "medio", True, "static int compat_do_execve("),

    # ---- fs/open.c -------------------------------------------------------
    ("fs/open.c", "decl faccessat",
     "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename,"
     " int, mode)\n",
     DECL_FACCESSAT, "antes", True, None),
    # lookup_flags = LOOKUP_FOLLOW aparece 3 veces en open.c: hay que acotar.
    ("fs/open.c", "faccessat",
     "\tunsigned int lookup_flags = LOOKUP_FOLLOW;\n",
     "\n#ifdef CONFIG_KSU\n"
     "\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n"
     "#endif\n", "despues", True,
     "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename"),

    # ---- fs/stat.c -------------------------------------------------------
    ("fs/stat.c", "decl stat",
     "#if !defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_SYS_NEWFSTATAT)\n",
     DECL_STAT, "antes", True, None),
    ("fs/stat.c", "newfstatat",
     "\terror = vfs_fstatat(dfd, filename, &stat, flag);\n",
     "#ifdef CONFIG_KSU\n"
     "\tksu_handle_stat(&dfd, &filename, &flag);\n"
     "#endif\n", "antes", True, "SYSCALL_DEFINE4(newfstatat"),
    ("fs/stat.c", "fstatat64",
     "\terror = vfs_fstatat(dfd, filename, &stat, flag);\n",
     "#ifdef CONFIG_KSU\n"
     "\tksu_handle_stat(&dfd, &filename, &flag);\n"
     "#endif\n", "antes", True, "SYSCALL_DEFINE4(fstatat64"),
    ("fs/stat.c", "newfstat ret",
     "\t\terror = cp_new_stat(&stat, statbuf);\n\n\treturn error;\n",
     "#if defined(CONFIG_KSU) && !defined(CONFIG_KSU_KPROBES_KSUD)\n"
     "\tksu_handle_newfstat_ret(&fd, &statbuf);\n"
     "#endif\n", "medio", True, "SYSCALL_DEFINE2(newfstat"),
    ("fs/stat.c", "fstat64 ret",
     "\t\terror = cp_new_stat64(&stat, statbuf);\n\n\treturn error;\n",
     "#if defined(CONFIG_KSU) && !defined(CONFIG_KSU_KPROBES_KSUD)\n"
     "\tksu_handle_fstat64_ret(&fd, &statbuf);\n"
     "#endif\n", "medio", True, "SYSCALL_DEFINE2(fstat64"),

    # ---- kernel/reboot.c -------------------------------------------------
    ("kernel/reboot.c", "decl reboot",
     "SYSCALL_DEFINE4(reboot, int, magic1, int, magic2, unsigned int, cmd,\n",
     DECL_REBOOT, "antes", True, None),
    ("kernel/reboot.c", "sys_reboot",
     "\tint ret = 0;\n",
     "\n#if defined(CONFIG_KSU) && !defined(CONFIG_KSU_KPROBES_KSUD)\n"
     "\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n"
     "#endif\n", "despues", True, "SYSCALL_DEFINE4(reboot"),
]

# Reemplazos simples (viejo -> nuevo). El policy_rwlock es opcional.
REEMPLAZOS = [
    ("security/selinux/ss/services.c", "policy_rwlock",
     "static DEFINE_RWLOCK(policy_rwlock);",
     "DEFINE_RWLOCK(policy_rwlock);", False),
]


def tramo(texto, desde):
    """Devuelve (inicio, fin) del cuerpo de la función que arranca en 'desde'.

    El fin incluye el "\\n}\\n" de cierre: si se cortara antes, un ancla que
    termina en la última línea de la función (p. ej. "\\treturn error;\\n") se
    quedaría sin su salto de línea final y no calzaría nunca.
    """
    i = texto.find(desde)
    if i < 0:
        return None
    j = texto.find("\n}\n", i)
    return (i, j + 3 if j > 0 else len(texto))


def aplicar(raiz):
    cambios, saltados, errores = [], [], []

    for arch, etiq, ancla, texto_nuevo, donde, obligatorio, desde in HOOKS:
        ruta = os.path.join(raiz, arch)
        if not os.path.exists(ruta):
            errores.append(f"{arch}: no existe")
            continue
        src = open(ruta, encoding="utf8", errors="surrogateescape").read()

        # ¿ya aplicado?
        marca = texto_nuevo.strip().splitlines()[1].strip()
        lim = tramo(src, desde) if desde else (0, len(src))
        if lim is None:
            errores.append(f"{arch} [{etiq}]: no se encontró la función {desde!r}")
            continue
        ini, fin = lim
        if marca in src[ini:fin]:
            saltados.append(f"{arch} [{etiq}]")
            continue

        n = src[ini:fin].count(ancla)
        if n != 1:
            errores.append(f"{arch} [{etiq}]: el ancla aparece {n} veces "
                           f"(se esperaba 1)")
            continue

        pos = src.index(ancla, ini)
        if donde == "antes":
            nuevo = src[:pos] + texto_nuevo + src[pos:]
        elif donde == "despues":
            nuevo = src[:pos + len(ancla)] + texto_nuevo + src[pos + len(ancla):]
        else:  # 'medio': el ancla son dos líneas y el hook va entre ellas
            corte = ancla.rindex("\n", 0, len(ancla) - 1) + 1
            nuevo = (src[:pos + corte] + texto_nuevo + src[pos + corte:])

        open(ruta, "w", encoding="utf8", errors="surrogateescape").write(nuevo)
        cambios.append(f"{arch} [{etiq}]")

    for arch, etiq, viejo, nuevo_txt, obligatorio in REEMPLAZOS:
        ruta = os.path.join(raiz, arch)
        if not os.path.exists(ruta):
            (errores if obligatorio else saltados).append(f"{arch}: no existe")
            continue
        src = open(ruta, encoding="utf8", errors="surrogateescape").read()
        if viejo not in src:
            if nuevo_txt in src:
                saltados.append(f"{arch} [{etiq}]")
            else:
                (errores if obligatorio else saltados).append(
                    f"{arch} [{etiq}]: no se encontró el patrón (opcional)")
            continue
        open(ruta, "w", encoding="utf8", errors="surrogateescape").write(
            src.replace(viejo, nuevo_txt, 1))
        cambios.append(f"{arch} [{etiq}]")

    print("  APLICADOS:")
    for c in cambios:
        print(f"    + {c}")
    if saltados:
        print("  ya estaban / omitidos:")
        for s in saltados:
            print(f"    . {s}")
    if errores:
        print("  ERRORES:")
        for e in errores:
            print(f"    ! {e}")
        return 1

    obligatorios = sum(1 for h in HOOKS if h[5])
    if len(cambios) + len(saltados) < obligatorios:
        print(f"  ERROR: solo {len(cambios)} de {obligatorios} hooks obligatorios")
        return 1
    print(f"\n  {len(cambios)} hooks aplicados, {len(saltados)} ya presentes.")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write(__doc__)
        sys.exit(2)
    sys.exit(aplicar(sys.argv[1]))
