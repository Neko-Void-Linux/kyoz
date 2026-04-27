# COMPILE
```
zig build-exe kyo.zig
```
# INSTALL
```
cp kyo ~/.local/bin/ 
```

# For compile do you need Zig
```
sudo xbps-install -S zig 
```
# Usage: 
kyo {install|update|remove|search|clean} [arguments...]

Commands:
  install, i   <package...>   Install packages
  
  update, u                   Update the system
  
  remove, r    <package...>   Remove packages (with -o)
  
  search, s    <term...>      Search for packages
  
  clean, c                    Clean orphans and obsolete packages

- example: for install fastfetch run...
kyo install fastfetch
or
kyo i fastfetch