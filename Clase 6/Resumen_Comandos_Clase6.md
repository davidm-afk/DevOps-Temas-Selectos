# Resumen de Comandos — Clase 6: SSH y Ansible

> Referencia rápida de todos los comandos prácticos de la sesión.

---

## SSH: Llaves y Acceso Sin Contraseña

```bash
useradd ansible && passwd ansible
echo "127.0.0.1   nodo1" >> /etc/hosts
ssh-keygen -t ed25519 -C "root@control"      # Genera par de llaves
ssh-copy-id ansible@nodo1                    # Copia la .pub al servidor
ssh ansible@nodo1 hostname                   # Acceso sin contraseña
ssh ansible@nodo1 'hostname; whoami; uptime' # Comandos sin shell interactiva
cat ~/.ssh/known_hosts                       # Huellas de servidores conocidos
cat /home/ansible/.ssh/authorized_keys       # Llave pública del cliente
chmod 700 /home/ansible/.ssh                 # Permisos correctos
chmod 600 /home/ansible/.ssh/authorized_keys
```

## Transferencia de Archivos

```bash
# scp
scp archivo.txt ansible@nodo1:/home/ansible/      # local → remoto
scp ansible@nodo1:/etc/os-release /tmp/           # remoto → local
scp -r /root/carpeta ansible@nodo1:~              # carpeta completa

# rsync
rsync -avz /origen/ ansible@nodo1:/destino/       # con barra: copia CONTENIDO
rsync -avz /origen  ansible@nodo1:/destino/       # sin barra: copia CARPETA
rsync -avz --delete --dry-run /origen/ ansible@nodo1:/destino/   # simulación

# sftp
sftp ansible@nodo1
sftp> ls; pwd; get archivo.txt; put local.txt; bye
```

## Ansible: Instalación y Configuración

```bash
dnf install -y ansible-core
ansible --version
mkdir -p /root/devops2026/ansible/templates && cd /root/devops2026/ansible
ansible-inventory --graph
ansible all --list-hosts
```

## Comandos Ad-hoc

```bash
ansible all -m ansible.builtin.ping
ansible nodo1 -m ansible.builtin.setup -a "filter=ansible_distribution*"
ansible nodo1 -m ansible.builtin.setup -a "filter=ansible_memtotal_mb"
ansible nodo1 -m ansible.builtin.command -a "df -h /"
ansible web -b -m ansible.builtin.dnf -a "name=tree state=present"
ansible web -m ansible.builtin.lineinfile -a "path=/home/ansible/notas.txt line='zona=aves' create=true"
ansible web -m ansible.builtin.copy -a "src=/root/reporte.txt dest=/home/ansible/ mode=0640"
ansible web -b -m ansible.builtin.file -a "path=/opt/zoologico state=directory mode=0755"
ansible web -b -m ansible.builtin.user -a "name=koala comment='Cuidador koalas'"
ansible web -b -m ansible.builtin.user -a "name=koala state=absent remove=true"
ansible web -b -m ansible.builtin.service -a "name=sshd state=started enabled=true"
ansible-doc -l | wc -l
ansible-doc ansible.builtin.user
ansible-doc -s ansible.builtin.lineinfile
```

## Playbooks

```bash
ansible-playbook <playbook>.yml --syntax-check   # Validar YAML
ansible-playbook <playbook>.yml --check --diff   # Simulación (dry-run)
ansible-playbook <playbook>.yml                  # Ejecutar
ansible-playbook <playbook>.yml -e "var=valor"   # Sobrescribir variable
id panda; ls -ld /opt/zoologico                  # Verificar usuarios.yml
curl -s localhost:8088                           # Verificar web.yml
curl -s localhost:8088/salud.html                # → OK
```

