# Temas Selectos de Ingeniería en Computación - Devops

## Instalación de Máquina Virtual
> VMware Workstation Pro
- Instalar el sistema operativo después
- Red Hat Linux 9.7 - 9.8
- Network connection: NAT
- Virtual Disk: NVMe
- Disk: Create virtual Disk

### Particiones del Disco (Disco de 10 GiB)
Particiones LVM (Grupo `rl`):
- `/` - 4 GiB
- `/home` - 1024 MiB
- `/var` - 1024 MiB
- `swap` - 1024 MiB
- `/tmp` - 1024 MiB

Particiones físicas (Standard Partition):
- `/boot` - 1024 MiB
- `/boot/efi` - 600 MiB

> *Nota: Con este esquema en un disco de 10 GiB quedan aprox. ~422 MiB libres en el Volume Group `rl` para realizar los ejercicios de `lvextend` y `lvcreate` de la clase.*

Base selection
- Minimal install

Kdump: Desabilitado y Allow SSH Login with password

### Particiones Físicas y LVM
- Física
- Grupo `vgcreate rl`
- Particiones lógicas
> `vgs // Para crear particiones` 

1. Crear la partición
> `parted // Para crear particiones` 

> `mkpart // Para crear la partición` 

> `lsblk` 
2. Crear el physical volume
> `pvcreate // Crear el volumen` 
> `pvs // mostrar los volumenes`
3. Extender el physical volume group
> `vgextend rl // extender los volumenes`
4. Extender la partición
> `lvextend -Lv 4.41G <particion> // extender una partición del mismo grupo`

> `lvcreate // crear partición`
5. Extender el formato 
> `xfs_grow //`

> `mkfs.fs // Darle formato`

6. Montar el volumen en caso de que sea una nueva partición
> `mkdir /test01 //`
> `mount <particion> <directorio> //`

7. Hacer permanente el volumen (con vi o nano)
> `vi /etc/fstab // Modificar el archivo`

> `mount -a // Validar errores`

> `systemctl daemon-reload // Best-practices`


 