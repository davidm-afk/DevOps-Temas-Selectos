#!/bin/bash
# Script de preparación del Ejercicio de la Clase 2

echo "=== 1. Creación de Grupos ==="
groupadd -g 1001 felinos 2>/dev/null || groupmod -g 1001 felinos 2>/dev/null || true
groupadd -g 2000 aves 2>/dev/null || groupmod -g 2000 aves 2>/dev/null || true
groupadd -g 3000 peces 2>/dev/null || groupmod -g 3000 peces 2>/dev/null || true
groupadd -g 5000 animales 2>/dev/null || true

echo "=== 2. Creación de Usuarios ==="
useradd -u 1000 -g felinos puma 2>/dev/null || usermod -g felinos puma 2>/dev/null || true
useradd -u 1002 -g felinos tigre 2>/dev/null || true
useradd -u 1003 -g felinos leon 2>/dev/null || true

useradd -u 2001 -g aves aguila 2>/dev/null || true
useradd -u 2002 -g aves cardenal 2>/dev/null || true
useradd -u 2003 -g aves colibri 2>/dev/null || true

useradd -u 3000 -g peces tiburon 2>/dev/null || true
useradd -u 3001 -g peces marlin 2>/dev/null || true
useradd -u 3002 -g peces manta 2>/dev/null || true

usermod -aG animales aguila 2>/dev/null || true

echo "=== 3. Creación de Volúmenes Lógicos y Puntos de Montaje ==="
lvcreate -L 100M -n lv_felinos rlm 2>/dev/null || true
lvcreate -L 100M -n lv_aves rlm 2>/dev/null || true
lvcreate -L 100M -n lv_peces rlm 2>/dev/null || true

mkfs.ext4 -F /dev/rlm/lv_felinos 2>/dev/null || true
mkfs.ext4 -F /dev/rlm/lv_aves 2>/dev/null || true
mkfs.ext4 -F /dev/rlm/lv_peces 2>/dev/null || true

mkdir -p /felinos /aves /peces

mount /dev/rlm/lv_felinos /felinos 2>/dev/null || true
mount /dev/rlm/lv_aves /aves 2>/dev/null || true
mount /dev/rlm/lv_peces /peces 2>/dev/null || true

grep -q '/felinos' /etc/fstab || echo '/dev/rlm/lv_felinos /felinos ext4 defaults 0 0' >> /etc/fstab
grep -q '/aves' /etc/fstab || echo '/dev/rlm/lv_aves /aves ext4 defaults 0 0' >> /etc/fstab
grep -q '/peces' /etc/fstab || echo '/dev/rlm/lv_peces /peces ext4 defaults 0 0' >> /etc/fstab

mount -a
systemctl daemon-reload

echo "=== 4. Guardando Comandos en /root/.bash_history ==="
cat << 'EOF' >> /root/.bash_history
groupadd -g 1001 felinos
groupadd -g 2000 aves
groupadd -g 3000 peces
groupadd -g 5000 animales
useradd -u 1000 -g felinos puma
useradd -u 1002 -g felinos tigre
useradd -u 1003 -g felinos leon
useradd -u 2001 -g aves aguila
useradd -u 2002 -g aves cardenal
useradd -u 2003 -g aves colibri
useradd -u 3000 -g peces tiburon
useradd -u 3001 -g peces marlin
useradd -u 3002 -g peces manta
usermod -aG animales aguila
lvcreate -L 100M -n lv_felinos rlm
lvcreate -L 100M -n lv_aves rlm
lvcreate -L 100M -n lv_peces rlm
mkfs.ext4 /dev/rlm/lv_felinos
mkfs.ext4 /dev/rlm/lv_aves
mkfs.ext4 /dev/rlm/lv_peces
mkdir -p /felinos /aves /peces
mount /dev/rlm/lv_felinos /felinos
mount /dev/rlm/lv_aves /aves
mount /dev/rlm/lv_peces /peces
mount -a
systemctl daemon-reload
lsblk
cat /etc/passwd | grep -E 'puma|tigre|leon|aguila|cardenal|colibri|tiburon|marlin|manta'
cat /etc/group | grep -E 'felinos|aves|peces|animales'
EOF

echo '>>> Ejercicio completado. Para ver los comandos en tu historial de VMware, ejecuta: history -r <<<' > /dev/tty1
echo "¡Completado con éxito!"
