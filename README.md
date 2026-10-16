# Kyoz

A simple and lightweight command-line wrapper for the [XBPS](https://wiki.voidlinux.org/XBPS) package manager on Void Linux.

## Requirements

- Void Linux
- [Zig](https://ziglang.org/) — only needed to build from source

## Installation

```sh
# Install Zig if you haven't already
sudo xbps-install -S zig

# Compile from source
zig build-exe kyo.zig

# Install the binary
cp kyo ~/.local/bin/
```

Make sure `~/.local/bin` is in your `PATH`.

## Usage

```sh
kyo {install|update|remove|search|clean} [arguments...]
```

| Command | Alias | Arguments | Description |
| :--- | :---: | :---: | :--- |
| `install` | `i` | `<packages>` | Install packages |
| `update` | `u` | — | Update the system |
| `remove` | `r` | `<packages>` | Remove packages (with `-o`) |
| `search` | `s` | `<query>` | Search for packages |
| `clean` | `c` | — | Clean orphans and obsolete packages |

## Examples

```sh
# Install fastfetch
kyo install fastfetch

# Using the short alias
kyo i fastfetch
```

## License

Released under the [WTFPL](http://www.wtfpl.net/).
