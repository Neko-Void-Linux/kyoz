# Kyoz

A simple, lightweight wrapper for the [XBPS](https://wiki.voidlinux.org/XBPS) package manager on Void Linux, written in [Zig](https://ziglang.org/).

## Requirements

- Void Linux
- [Zig](https://ziglang.org/) 0.14.x - only needed to build from source
- `sudo` at runtime for package operations

## Build

```sh
# Install Zig if you haven't already
sudo xbps-install -S zig

# Get the sources and compile
git clone https://github.com/Neko-Void-Linux/kyoz
cd kyoz
zig build-exe kyo.zig -O ReleaseSafe
```

## Install

```sh
install -Dm 755 kyo ~/.local/bin/kyo
```

Make sure `~/.local/bin` is in your `PATH`.

You can also grab a prebuilt binary from the [latest release](https://github.com/Neko-Void-Linux/kyoz/releases/latest).

## Usage

```sh
kyo {install|update|remove|search|clean} [arguments...]
```

Run `kyo --h` (`-h` or `--help` also work) to show every available option.

| Command | Alias | Arguments | Description |
| :--- | :---: | :---: | :--- |
| `install` | `i` | `<packages>` | Install packages |
| `update` | `u` | — | Update the system |
| `remove` | `r` | `<packages>` | Remove packages (with `-o`) |
| `search` | `s` | `<query>` | Search for packages |
| `clean` | `c` | — | Clean orphans and obsolete packages |

## Interactive menu

Running `kyo` with no arguments on a terminal opens a fullscreen interactive menu:

| Key | Action |
| :--- | :--- |
| `↑` / `↓` (or `k` / `j`) | Move |
| `Enter` | Select |
| `i` or `?` | Info screen |
| `q` (or `Ctrl-C`) | Quit |

It can also be opened explicitly with `kyo tui` (or `kyo menu`).

## Examples

```sh
# Install fastfetch
kyo install fastfetch
kyo i fastfetch

# Search for a package
kyo search neovim
```

## License

Released under the [WTFPL](http://www.wtfpl.net/).
