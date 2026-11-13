#!/bin/bash
set -e

echo "=== 1. Probando Contenedores Nginx y Volumen ==="
curl -s http://localhost:8080 | head -n 4
MP=$(podman volume inspect volngnix --format '{{.Mountpoint}}')
echo "<h1>Sitio con Volumen Persistente</h1>" > "$MP/index.html"
curl -s http://localhost:8082

echo "=== 2. Proyecto 1: Webserver Python Puro ==="
mkdir -p /root/web-python
cd /root/web-python

cat << 'PYEOF' > server.py
from http.server import HTTPServer, BaseHTTPRequestHandler
import datetime
import json
import os
import socket

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            body = json.dumps({"status": "ok", "app": "python-podman"}).encode()
            ctype = "application/json"
        else:
            html = (
                "<h1>Hola desde Podman en Rocky Linux</h1>"
                f"<p>Contenedor: {socket.gethostname()}</p>"
                f"<p>Hora: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}</p>"
            )
            body = html.encode()
            ctype = "text/html; charset=utf-8"

        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    print(f"Escuchando en 0.0.0.0:{port}")
    HTTPServer(("0.0.0.0", port), Handler).serve_forever()
PYEOF

cat << 'C1EOF' > Containerfile
FROM docker.io/library/python:3.11-slim
LABEL description="Webserver en Python puro con http.server"
WORKDIR /app
RUN useradd -u 1001 -m appuser
COPY --chown=1001:1001 server.py .
ENV PORT=8080 PYTHONUNBUFFERED=1
EXPOSE 8080
USER 1001
CMD ["python", "server.py"]
C1EOF

podman build -t py-web:1.0 .
podman stop nginx02 2>/dev/null || true
podman run -d --replace --name web -p 8080:8080 py-web:1.0
sleep 2
curl -s http://localhost:8080
echo ""
curl -s http://localhost:8080/health
echo ""
podman logs web

echo "=== 3. Proyecto 2: Base de Datos PostgreSQL con Usuarios y Datos ==="
mkdir -p /root/db-postgres
cd /root/db-postgres

cat << 'SQLEOF' > init.sql
CREATE USER app_user WITH PASSWORD 'App2026!';
CREATE USER reporte  WITH PASSWORD 'Rep2026!';

CREATE DATABASE inventario OWNER app_user;

\connect inventario

CREATE TABLE productos (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(100) NOT NULL,
    cantidad  INTEGER      NOT NULL DEFAULT 0,
    creado    TIMESTAMP    NOT NULL DEFAULT now()
);
ALTER TABLE productos OWNER TO app_user;

INSERT INTO productos (nombre, cantidad) VALUES
    ('Servidor ProLiant', 4),
    ('Switch 48p', 2),
    ('Disco NVMe 3.84TB', 12);

GRANT CONNECT ON DATABASE inventario TO reporte;
GRANT USAGE   ON SCHEMA public       TO reporte;
GRANT SELECT  ON ALL TABLES IN SCHEMA public TO reporte;
ALTER DEFAULT PRIVILEGES FOR ROLE app_user IN SCHEMA public
    GRANT SELECT ON TABLES TO reporte;
SQLEOF

cat << 'C2EOF' > Containerfile
FROM docker.io/library/postgres:16
LABEL description="PostgreSQL con usuarios y datos iniciales"
COPY init.sql /docker-entrypoint-initdb.d/01-init.sql
ENV TZ=America/Mexico_City
EXPOSE 5432
C2EOF

podman build -t pg-usuarios:1.0 .
podman volume create pgdata 2>/dev/null || true
podman run -d --replace --name db \
  -e POSTGRES_PASSWORD='Admin2026!' \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data:Z \
  pg-usuarios:1.0

echo "Esperando que PostgreSQL inicialice la base de datos..."
for i in {1..30}; do
  if podman exec db pg_isready -U postgres 2>/dev/null; then
    break
  fi
  sleep 2
done

echo "Usuarios en PostgreSQL:"
podman exec -i db psql -U postgres -c '\du'

echo "Consulta como app_user:"
podman exec -i db psql -U app_user -d inventario -c 'SELECT * FROM productos;'

echo "Consulta como reporte (solo lectura):"
podman exec -i db psql -U reporte  -d inventario -c 'SELECT count(*) FROM productos;'

echo "=== 4. Proyecto 3: Ubuntu con Actualización y Usuarios desde usuarios.txt ==="
mkdir -p /root/ubuntu-usuarios
cd /root/ubuntu-usuarios

cat << 'TXTEOF' > usuarios.txt
# Las lineas con # y las vacias se ignoran
daniel:Daniel2026!
ana:Ana2026!
alumno1:Alumno2026!
alumno2:Alumno2026!
TXTEOF

cat << 'C3EOF' > Containerfile
FROM docker.io/library/ubuntu:24.04
LABEL description="Ubuntu actualizado con usuarios desde usuarios.txt"
ENV DEBIAN_FRONTEND=noninteractive TZ=America/Mexico_City

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y --no-install-recommends sudo tzdata vim-tiny iputils-ping && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

COPY usuarios.txt /tmp/usuarios.txt

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
C3EOF

podman build -t ubuntu-usuarios:1.0 .

echo "Verificando grupo devops en el contenedor Ubuntu:"
podman run --rm ubuntu-usuarios:1.0 getent group devops

echo "Verificando carpetas de usuarios creadas en /home:"
podman run --rm ubuntu-usuarios:1.0 ls -la /home

echo "=== TODOS LOS LABORATORIOS DE LA CLASE 4 COMPLETADOS CON ÉXITO ==="
