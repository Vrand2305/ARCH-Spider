#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export LIBVIRT_DEFAULT_URI="qemu:///system"
export PATH="/usr/lib/qt6/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

alias win-low='virsh --connect qemu:///system setmem win11 3G --live'
alias win-normal='virsh --connect qemu:///system setmem win11 4G --live'
alias win-high='virsh --connect qemu:///system setmem win11 6G --live'
spiderfetch
eval "$(starship init bash)"

# Redibujar SpiderFetch al redimensionar Konsole
_spider_resize() {
    clear
    spiderfetch
}

trap '_spider_resize' WINCH
