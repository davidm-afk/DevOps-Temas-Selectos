Creacion de usuarios y grupos

Tenemos una carpeta /etc/passwd donde existen todos los usuarios del sistema operativo como los que vamos a ir creando


Tenemos el archivo shadow, cat /etc/shadow en donde podemos obtener las contraseñas de los usuarios con su respesctivo nivel de encriptacion

Tenemos el archivo group, cat /etc/group en donde se muestran todos los grupos que se han creado


useradd puma
cat /etc/passwd | grep puma 
cat /etc/shadow | grep puma
cat /etc/group | grep puma

groupadd felinos
cat /etc/group | grep felinos

groupadd --help

groupadd -g 2000 aves
groupadd -g 3000 peces

useradd -u 2001 -G aves aguila
cat etc/passwd | grep aguila
cat etc/group | grep aguila
cat etc/shadow | grep aguila

groupadd -g 5000 animales
usermod -G 5000 aguila
cat /etc/group | grep aguila

usermod -G 5000 -G 2000 aguila --> NO deja entonces usamos VI

vi /etc/group --> editar manualmente


Ejercicio:
Crear tres particiones (logical volume) y montarlas de 100Mb cada una de ellas

/aves
/peces
/felinos

Generar 9 usuarios y 3 grupos

GRUPOS: FELINOS, AVECES, PECES
USUARIOS: PUMA, TIGRE, LEON, AGUILA, CADERNAL COLIBRI, TIBURON, MARLIN Y COLIBRI

Cada usuario tiene que estar en un grupo determinado

Grupos con id especifico
felinos 1001, aves 2000, peces 3000

Usuarios de felinos deben tener id entre 1000 y 1999
Usuarios de aves con id entre 2001 y 2999
Usuarios de peces con id entre 3000 y 3999

FIN EJERCICIO


Tenemos 2 formas de compartir permisos

ls -l
total 4
-rw-------. 1 root root 1277 sep  3 21:30 anaconda-ks.cfg

-rw-------  
Los primeros 3 valores correponden a grupos usuarios y otros
r=4
w=2
x=1

con el comando chmod podemos ocupar comandos para permisos

[root@localhost ~]# ls -ld /aves/
drwxr-xr-x. 3 root root 1024 sep  4 07:51 /aves/
¿que permisos tiene?

Cambiar al grupo de aves
[root@localhost ~]# chgrp aves /aves
[root@localhost ~]# ls -ld /aves/
drwxr-xr-x. 3 root aves 1024 sep  4 07:51 /aves/

Cambiaremos permisos para que los que no sean del grupo de aves no puedan hacer nada

[root@localhost ~]# chmod 770 /aves
[root@localhost ~]# ls -ld /aves
drwxrwx---. 3 root aves 1024 sep  4 07:51 /aves

su -puma
cd /aves --> no deja entrar

su - aguila
cd /aves --> deja entrar

Cambiar grupo y permisos de felinos:
[root@localhost ~]# chgrp felinos /felinos
[root@localhost ~]# chmod  770 /felinos
[root@localhost ~]# ls -ld /felinos
drwxrwx---. 3 root felinos 1024 sep  4 07:51 /felinos

Cambiar grupo y permisos de peces:
[root@localhost ~]# chgrp peces /peces
[root@localhost ~]# chmod  770 /peces
[root@localhost ~]# ls -ld /peces
drwxrwx---. 3 root peces 1024 sep  4 07:51 /peces

 "nota: vgs sirve para verificar el espacio en disco"

 Ejercicio:
 ¿Como hacemos si queremos que puma pueda escribir en la carpeta de aves?
 REGLAS ACL (generar excepciones) access control list
    getfacl /aves --> obtenemos informacion de los permisos

    setfacl -m u:puma:rwx /aves --> le asignamos permisos a puma para escribir en aves

    getfacl /aves --> verificamos cambios
    [root@localhost /]# getfacl /aves
getfacl: Eliminando '/' inicial en nombres de ruta absolutos
# file: aves
# owner: root
# group: aves
user::rwx
group::rwx
other::---

entramos al usuario puma
[root@localhost /]# su - puma



ahora puma puede entrar a la carpeta de aves
[root@localhost ~]# su - puma
[puma@localhost ~]$ cd /aves
[puma@localhost aves]$ touch text.text
[puma@localhost aves]$ ls -l
total 12
drwx------. 2 root root 12288 sep  4 07:51 lost+found
-rw-r--r--. 1 puma puma     0 sep  4 08:42 text.text
[puma@localhost aves]$ ls
lost+found  text.text






Cada que se genere un archivo y un directorio. Los privilegios maximos de un directorio es 777, los privilegios maximos de un archivo es 666

Regla umask la cual por default es 022

para directorios nos lo va generar con permisos 755  777 - 022 = 755
Para arcivos nos lo va generar con permisos 644  666-022 = 644

[puma@localhost aves]$ mkdir test01
[puma@localhost aves]$ ls -ld test01/
drwxr-xr-x. 2 puma puma 1024 sep  4 08:45 test01/




para quitarle permisos a otros y a grupos el umask queda como 077

[root@localhost ~]# umask 0077
[root@localhost ~]# su - puma
Último inicio de sesión: vie sep  4 08:41:55 CST 2026 en pts/0
[puma@localhost ~]$ umask
0022
[puma@localhost ~]$ umask 0077






nota :comando dnf whatprovides nc
[root@localhost ~]# dnf install nmap-ncat

La otra opcion es usar un disco de instalacion

cd /etc/yum.repos.d
cat /rocky.repo

[root@localhost ~]# cd /etc/yum.repos.d
[root@localhost yum.repos.d]# ls
rocky-addons.repo  rocky-devel.repo  rocky-extras.repo  rocky.repo  rocky-security.repo
[root@localhost yum.repos.d]# cat /rocky.repo
cat: /rocky.repo: No existe el fichero o el directorio
[root@localhost yum.repos.d]# cat rocky.repo
# rocky.repo
#
# The mirrorlist system uses the connecting IP address of the client and the
# update status of each mirror to pick current mirrors that are geographically
# close to the client.  You should use this for Rocky updates unless you are
# manually picking other mirrors.
#
# If the mirrorlist does not work for you, you can try the commented out
# baseurl line instead.

[baseos]
name=Rocky Linux $releasever - BaseOS
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=BaseOS-$releasever$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/BaseOS/$basearch/os/
gpgcheck=1
enabled=1
countme=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[baseos-debuginfo]
name=Rocky Linux $releasever - BaseOS - Debug
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=BaseOS-$releasever-debug$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/BaseOS/$basearch/debug/tree/
gpgcheck=1
enabled=0
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[baseos-source]
name=Rocky Linux $releasever - BaseOS - Source
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=BaseOS-$releasever-source$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/BaseOS/source/tree/
gpgcheck=1
enabled=0
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[appstream]
name=Rocky Linux $releasever - AppStream
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=AppStream-$releasever$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/AppStream/$basearch/os/
gpgcheck=1
enabled=1
countme=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[appstream-debuginfo]
name=Rocky Linux $releasever - AppStream - Debug
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=AppStream-$releasever-debug$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/AppStream/$basearch/debug/tree/
gpgcheck=1
enabled=0
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[appstream-source]
name=Rocky Linux $releasever - AppStream - Source
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=AppStream-$releasever-source$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/AppStream/source/tree/
gpgcheck=1
enabled=0
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[crb]
name=Rocky Linux $releasever - CRB
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=CRB-$releasever$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/CRB/$basearch/os/
gpgcheck=1
enabled=0
countme=1
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[crb-debuginfo]
name=Rocky Linux $releasever - CRB - Debug
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=$basearch&repo=CRB-$releasever-debug$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/CRB/$basearch/debug/tree/
gpgcheck=1
enabled=0
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10

[crb-source]
name=Rocky Linux $releasever - CRB - Source
mirrorlist=https://mirrors.rockylinux.org/mirrorlist?arch=source&repo=CRB-$releasever-source$rltype
#baseurl=http://dl.rockylinux.org/$contentdir/$releasever/CRB/source/tree/
gpgcheck=1
enabled=0
metadata_expire=6h
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-10



Podemos hacer el archivo rocky.repo a un disco de instalacion, esto es util para maquinas  sin acceso a internet

[root@localhost yum.repos.d]# mv rocky* /root/
[root@localhost yum.repos.d]# ls
[root@localhost yum.repos.d]# vi cdrom.repo
[BaseOs]                                                                                            name=BaseOS                                                                                          baseurl=file:///mnt/BaseOS                                                                                               enabled=1                                                                  gpgcheck=0                                                                                    [AppStream]                                                                                name=AppStream                                                                                       baseurl=file:///mnt/AppStream                                                                                             enabled=1                                                                                            gpgcheck=0 

mount /dev/cdrom /mnt/   nota: los mount solo duran hasta que se apaga el equipo 
cd /mnt/
ls
dnf clean all
dnf install httpd
dnf list | wc -l
