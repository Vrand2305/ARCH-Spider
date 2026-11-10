# ARCH-Spider

Backup reproducible de la personalización de Arch Linux: KDE Plasma, widgets, Conky, Dynamic Island, Fish/Starship, temas, atajos y paquetes.

## Instalación

Revisar primero los archivos y luego ejecutar:

```bash
./install.sh
```

El instalador crea una copia de seguridad en `~/.config/ARCH-Spider-backup-*` antes de reemplazar configuraciones.

## Contenido

- `config/`: configuraciones seleccionadas de Plasma, widgets, shell y temas.
- `home/`: archivos de inicio del usuario.
- `packages-pacman.txt`: paquetes oficiales.
- `packages-aur.txt`: paquetes AUR instalados.
- `user-services-enabled.txt`: servicios de usuario habilitados.

No se incluyen contraseñas, tokens, claves SSH, perfiles de navegador ni cachés.
