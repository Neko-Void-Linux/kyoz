# Kyoz

[English](README.md) | **Español**

Un wrapper simple y ligero para el gestor de paquetes [XBPS](https://wiki.voidlinux.org/XBPS) en Void Linux, escrito en [Zig](https://ziglang.org/).

## Requisitos

- Void Linux
- [Zig](https://ziglang.org/) 0.17.x - solo es necesario para compilar desde el código fuente
- `sudo`, `doas` o `su` en tiempo de ejecución para las operaciones de paquetes (se usa el primero que se encuentre en el `PATH`; `su -c` es el último recurso)

## Compilación

```sh
# Instala Zig si aún no lo tienes
sudo xbps-install -S zig

# Obtén el código fuente y compila
git clone https://github.com/Neko-Void-Linux/kyoz
cd kyoz
zig build-exe kyo.zig -O ReleaseSafe
```

## Instalación

```sh
install -Dm 755 kyo ~/.local/bin/kyo
```

Asegúrate de que `~/.local/bin` esté en tu `PATH`.

También puedes descargar un binario precompilado desde la [última release](https://github.com/Neko-Void-Linux/kyoz/releases/latest).

## Uso

```sh
kyo {install|update|remove|search|clean} [argumentos...]
```

Ejecuta `kyo --h` (`-h` o `--help` también funcionan) para ver todas las opciones disponibles, y `kyo --version` (`-v` también funciona) para mostrar la versión.

| Comando | Alias | Argumentos | Descripción |
| :--- | :---: | :---: | :--- |
| `install` | `i` | `<paquetes>` | Instalar paquetes |
| `update` | `u` | — | Actualizar el sistema |
| `remove` | `r` | `<paquetes>` | Eliminar paquetes (con `-o`) |
| `search` | `s` | `<término>` | Buscar paquetes |
| `clean` | `c` | — | Limpiar paquetes huérfanos y obsoletos |

## Menú interactivo

Ejecutar `kyo` sin argumentos en una terminal abre un menú interactivo a pantalla completa:

<img width="731" height="513" alt="image" src="https://github.com/user-attachments/assets/caf36de5-35db-422f-8865-baf72c7adfb3" />


| Tecla | Acción |
| :--- | :--- |
| `↑` / `↓` (o `k` / `j`) | Moverse |
| `Enter` | Seleccionar |
| `i` o `?` | Pantalla de información |
| `q` (o `Ctrl-C`) | Salir |

También se puede abrir explícitamente con `kyo tui` (o `kyo menu`).

## Ejemplos

```sh
# Instalar fastfetch
kyo install fastfetch
kyo i fastfetch

# Buscar un paquete
kyo search neovim
```

## Licencia

Publicado bajo la [WTFPL](http://www.wtfpl.net/).
