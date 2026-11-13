# Reporte de Entrega: Tarea Clase 4 - Podman y Containerfiles

> **Asignatura:** Temas Selectos de Ingeniería en Computación - DevOps  
> **Tema:** Despliegue de los dos contenedores restantes del artefacto de Claude (`db-postgres` y `ubuntu-usuarios`).  
> **Entorno de ejecución:** Rocky Linux 10.2 (Red Quartz) - Kernel Linux x86_64  
> **Motor de contenedores:** Podman versión 5.8.2 (Modo Daemonless)  
> **Fecha de ejecución:** 24 de Septiembre de 2026

---

## 1. Objetivo de la Tarea

Seguir el artefacto de Claude (`tres-containerfiles-podman.html`) para implementar, compilar y validar los dos contenedores restantes:
1. **Contenedor 2 (`db-postgres`):** Base de datos PostgreSQL 16 con inicialización automatizada mediante `init.sql`, segregación de permisos entre usuario administrador (`app_user`) y usuario auditor de solo lectura (`reporte`), y almacenamiento persistente desacoplado en el host mediante un volumen gestionado (`pgdata`).
2. **Contenedor 3 (`ubuntu-usuarios`):** Imagen de Ubuntu 24.04 que se actualiza automáticamente durante el build, realiza alta masiva de cuentas leyendo un archivo de texto (`usuarios.txt`), asigna contraseñas cifradas y configura privilegios de administración en `sudoers.d`.

---

## 2. Ejercicio 1: Base de Datos PostgreSQL con Usuarios (`db-postgres`)

### 2.1 Archivos Fuente del Proyecto

#### Archivo: `/root/db-postgres/init.sql`
Script SQL que se copia a `/docker-entrypoint-initdb.d/01-init.sql` y se dispara automáticamente la primera vez que se inicializa el clúster:

```sql
-- Creación de usuarios con contraseñas seguras
CREATE USER app_user WITH PASSWORD 'App2026!';
CREATE USER reporte  WITH PASSWORD 'Rep2026!';

-- Base de datos asignada a app_user
CREATE DATABASE inventario OWNER app_user;

\connect inventario

-- Creación de tabla y asignación de propietario
CREATE TABLE productos (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    cantidad  INTEGER      NOT NULL DEFAULT 0,
    creado    TIMESTAMP    NOT NULL DEFAULT now()
);
ALTER TABLE productos OWNER TO app_user;

-- Inserción de datos iniciales
INSERT INTO productos (nombre, cantidad) VALUES
    ('Servidor ProLiant', 4),
    ('Switch 48p', 2),
    ('Disco NVMe 3.84TB', 12);

-- Configuración de permisos de solo lectura para el usuario reporte
GRANT CONNECT ON DATABASE inventario TO reporte;
GRANT USAGE   ON SCHEMA public       TO reporte;
GRANT SELECT  ON ALL TABLES IN SCHEMA public TO reporte;
ALTER DEFAULT PRIVILEGES FOR ROLE app_user IN SCHEMA public
    GRANT SELECT ON TABLES TO reporte;
```

#### Archivo: `/root/db-postgres/Containerfile`
```dockerfile
FROM docker.io/library/postgres:16

LABEL description="PostgreSQL con usuarios y datos iniciales"

# El script se ejecuta solo si el directorio de datos está vacío
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

ENV TZ=America/Mexico_City

EXPOSE 5432
```

---

### 2.2 Comandos de Construcción y Despliegue

```bash
# 1. Compilación de la imagen
cd /root/db-postgres
podman build -t pg-usuarios:1.0 .

# 2. Creación del volumen persistente en el host
podman volume create pgdata

# 3. Despliegue del contenedor con puerto publicado y bandera SELinux :Z
podman run -d --name db \
  -e POSTGRES_PASSWORD='Admin2026!' \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data:Z \
  pg-usuarios:1.0
```

---

### 2.3 Capturas de Validación del Contenedor PostgreSQL

#### 📸 Captura 1: Verificación del volumen persistente en el host
```text
[root@localhost ~]# podman volume inspect pgdata --format "Nombre: {{.Name}} | Punto de Montaje: {{.Mountpoint}}"
Nombre: pgdata | Punto de Montaje: /var/lib/containers/storage/volumes/pgdata/_data
```
> *Validación:* El directorio existe físicamente en el disco del servidor, garantizando que si el contenedor es destruido, los datos no se pierden.

#### 📸 Captura 2: Lista de roles y usuarios en PostgreSQL (`\du`)
```text
[root@localhost ~]# podman exec -i db psql -U postgres -c '\du'
                             List of roles
 Role name |                         Attributes                         
-----------+------------------------------------------------------------
 app_user  | 
 postgres  | Superuser, Create role, Create DB, Replication, Bypass RLS
 reporte   | 
```
> *Validación:* Se comprueba la creación automática de los roles `app_user` y `reporte` junto al superusuario `postgres`.

#### 📸 Captura 3: Consulta de datos como `app_user` (Propietario de la BD)
```text
[root@localhost ~]# podman exec -i db psql -U app_user -d inventario -c 'SELECT * FROM productos;'
 id |      nombre       | cantidad |           creado           
----+-------------------+----------+----------------------------
  1 | Servidor ProLiant |        4 | 2026-09-24 23:31:16.363331
  2 | Switch 48p        |        2 | 2026-09-24 23:31:16.363331
  3 | Disco NVMe 3.84TB |       12 | 2026-09-24 23:31:16.363331
(3 rows)
```
> *Validación:* El usuario `app_user` se conecta exitosamente a la base `inventario` y consulta los registros cargados por `init.sql`.

#### 📸 Captura 4: Consulta de solo lectura como usuario `reporte`
```text
[root@localhost ~]# podman exec -i db psql -U reporte -d inventario -c 'SELECT count(*) AS total_productos FROM productos;'
 total_productos 
-----------------
               3
(1 row)
```
> *Validación:* El rol `reporte` tiene permisos concedidos para realizar sentencias `SELECT`.

#### 📸 Captura 5: Prueba de restricción de seguridad (Intento de escritura con `reporte`)
```text
[root@localhost ~]# podman exec -i db psql -U reporte -d inventario -c "INSERT INTO productos(nombre) VALUES ('IntentoNoAutorizado');"
ERROR:  permission denied for table productos
```
> *Validación:* **La política de seguridad se cumple.** El usuario `reporte` no tiene privilegios de escritura (`INSERT`/`UPDATE`/`DELETE`) y la base de datos rechaza la operación.

---

## 3. Ejercicio 2: Ubuntu con Creación Masiva de Usuarios (`ubuntu-usuarios`)

### 3.1 Archivos Fuente del Proyecto

#### Archivo: `/root/ubuntu-usuarios/usuarios.txt`
Archivo plano con formato `usuario:contraseña` ubicado en el contexto de construcción:
```text
# Las lineas con # y las vacias se ignoran
daniel:Daniel2026!
ana:Ana2026!
alumno1:Alumno2026!
alumno2:Alumno2026!
```

#### Archivo: `/root/ubuntu-usuarios/Containerfile`
```dockerfile
FROM docker.io/library/ubuntu:24.04

LABEL description="Ubuntu actualizado con usuarios desde usuarios.txt"

ENV DEBIAN_FRONTEND=noninteractive TZ=America/Mexico_City

# 1. Actualizar el sistema e instalar herramientas básicas
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends sudo tzdata vim-tiny iputils-ping && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. Copiar archivo de usuarios desde el contexto local
COPY usuarios.txt /tmp/usuarios.txt

# 3. Procesar archivo, crear usuarios, asignar claves y configurar sudoers
RUN groupadd -f devops && \
    while IFS=: read -r usuario clave || [ -n "$usuario" ]; do \
      case "$usuario" in ''|'#'*) continue ;; esac; \
      useradd -m -s /bin/bash -G devops "$usuario"; \
      echo "$usuario:$clave" | chpasswd; \
      echo "Usuario creado: $usuario"; \
    done < /tmp/usuarios.txt && \
    echo '%devops ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/devops && \
    chmod 440 /etc/sudoers.d/devops && \
    rm -f /tmp/usuarios.txt

WORKDIR /home
CMD ["/bin/bash"]
```

---

### 3.2 Comando de Construcción
```bash
cd /root/ubuntu-usuarios
podman build -t ubuntu-usuarios:1.0 .
```

---

### 3.3 Capturas de Validación del Contenedor Ubuntu

#### 📸 Captura 6: Verificación del grupo `devops` y sus miembros
```text
[root@localhost ~]# podman run --rm localhost/ubuntu-usuarios:1.0 getent group devops
devops:x:1001:daniel,ana,alumno1,alumno2
```
> *Validación:* Todos los usuarios definidos en `usuarios.txt` fueron creados e integrados como miembros secundarios del grupo `devops` (GID 1001).

#### 📸 Captura 7: Verificación de los directorios personales en `/home`
```text
[root@localhost ~]# podman run --rm localhost/ubuntu-usuarios:1.0 ls -la /home
total 0
drwxr-xr-x. 1 root    root    61 Sep 24 23:31 .
dr-xr-xr-x. 1 root    root    28 Sep 24 23:33 ..
drwxr-x---. 2 alumno1 alumno1 57 Sep 24 23:31 alumno1
drwxr-x---. 2 alumno2 alumno2 57 Sep 24 23:31 alumno2
drwxr-x---. 2 ana     ana     57 Sep 24 23:31 ana
drwxr-x---. 2 daniel  daniel  57 Sep 24 23:31 daniel
drwxr-x---. 2 ubuntu  ubuntu  57 Sep 10 20:10 ubuntu
```
> *Validación:* Cada usuario cuenta con su directorio personal `/home/<usuario>` con permisos propietarios exclusivos (`750`).

#### 📸 Captura 8: Prueba de cambio de usuario y privilegios de `sudo`
```text
[root@localhost ~]# podman run --rm localhost/ubuntu-usuarios:1.0 su - daniel -c 'id; sudo apt list --upgradable | head -n 3'
uid=1001(daniel) gid=1002(daniel) groups=1002(daniel),1001(devops)

Listing...
```
> *Validación:* El usuario `daniel` inicia sesión con su identidad normal y ejecuta comandos con `sudo` sin que el sistema solicite contraseña, gracias a la regla configurada en `/etc/sudoers.d/devops`.

---

## 4. Estado Final del Servidor de Contenedores (`podman ps -a`)

```text
[root@localhost ~]# podman ps -a
CONTAINER ID  IMAGE                           COMMAND               CREATED         STATUS                    PORTS                   NAMES
1a653adc6f2c  docker.io/library/nginx:latest  nginx -g daemon o...  12 minutes ago  Up 12 minutes             80/tcp                  nginx01
e6610b6304c2  docker.io/library/nginx:latest  nginx -g daemon o...  12 minutes ago  Exited (0) 9 minutes ago  0.0.0.0:8080->80/tcp    nginx02
81bd05147f21  docker.io/library/nginx:latest  nginx -g daemon o...  12 minutes ago  Up 12 minutes             0.0.0.0:8081->80/tcp    nginx03
3e10449c292c  docker.io/library/nginx:latest  nginx -g daemon o...  12 minutes ago  Up 12 minutes             0.0.0.0:8082->80/tcp    ngnix04
35c21d0378f7  localhost/py-web:1.0            python server.py      6 minutes ago   Up 6 minutes              0.0.0.0:8080->8080/tcp  web
49789b08417b  localhost/pg-usuarios:1.0       postgres              5 minutes ago   Up 5 minutes              0.0.0.0:5432->5432/tcp  db
```

```text
[root@localhost ~]# podman images
REPOSITORY                  TAG         IMAGE ID      CREATED        SIZE
localhost/ubuntu-usuarios   1.0         dde5bb8b5d62  5 minutes ago  98.5 MB
localhost/pg-usuarios       1.0         68e9f267c044  5 minutes ago  458 MB
localhost/py-web            1.0         8441397a51ec  7 minutes ago  130 MB
docker.io/library/python    3.11-slim   274d131132db  6 days ago     130 MB
docker.io/library/postgres  16          1b3c642526f8  6 days ago     459 MB
docker.io/library/nginx     latest      e9567a94eddc  6 days ago     166 MB
docker.io/library/ubuntu    24.04       6232b3879100  13 days ago    80.7 MB
```

---

## 5. Conclusiones Técnicas

1. **Persistencia y SELinux:** La base de datos PostgreSQL requiere obligatoriamente la bandera `:Z` al mapear volúmenes locales en Rocky Linux con SELinux en `Enforcing`. Esto permite que el contenedor acceda al almacenamiento sin violar las políticas de seguridad del kernel.
2. **Segregación de Roles:** Se verificó que las políticas de base de datos son independientes de los permisos del sistema operativo; `reporte` puede leer pero tiene bloqueada cualquier alteración de registros.
3. **Automatización en el Build:** El procesamiento de `usuarios.txt` durante la construcción demuestra cómo generar imágenes preparadas para entornos empresariales donde no se admiten configuraciones manuales posteriores al despliegue.