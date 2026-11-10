fish_add_path $HOME/.local/bin /usr/lib/qt6/bin

if status is-interactive
    set -gx LIBVIRT_DEFAULT_URI qemu:///system

    alias win-low='virsh --connect qemu:///system setmem win11 3G --live'
    alias win-normal='virsh --connect qemu:///system setmem win11 4G --live'
    alias win-high='virsh --connect qemu:///system setmem win11 6G --live'

    command -q spiderfetch; and spiderfetch
    command -q starship; and starship init fish | source
end

# Added by codebase-memory-mcp install
fish_add_path /home/bporras@confia.local/.local/bin
