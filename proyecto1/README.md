# Proyecto 1: Caso de estudio Optimización de Bases de Datos y Big Data

## Objetivo del Trabajo
Aplicar técnicas avanzadas de optimización de consultas, particionamiento, índices y *performance tuning* a nivel de servidor (PostgreSQL) sobre una base de datos con un esquema OLTP estilo e-commerce escalada a más de 30 millones de registros. 

## Estructura del Directorio

* `/scripts/`: Contiene los archivos SQL para crear el esquema, generar los datos y aplicar las optimizaciones.
* `/docker/`: Archivos `docker-compose.yml` y configuraciones (`postgresql.conf`) para levantar la instancia local o en EC2.
* `/docs/`: Contiene el informe técnico final en formato PDF.
* `README.md`: Este archivo de documentación.
* * `/informes/`: Esta carpeta contiene el link al drive en donde estan subidos los progresos a lo largo del semestre en los informes 1 y 2.

## Arquitectura y Entorno Tecnológico

Las pruebas y mediciones se realizaron en dos entornos distintos para comparar rendimientos:
1. **AWS EC2 (Dockerizado):** Instancia Ubuntu corriendo PostgreSQL en un contenedor Docker con parámetros de memoria ajustados manualmente.
2. **AWS RDS:** Base de datos gestionada por Amazon Web Services, utilizando *Parameter Groups* para el *tuning*.

---
### Tecnologías Utilizadas:
* **Motor de Base de Datos:** PostgreSQL
* **Infraestructura:** AWS EC2, AWS RDS
* **Contenedores:** Docker & Docker Compose
* **Herramientas de Análisis:** EXPLAIN ANALYZE, PgAdmin / DBeaver
---

### Ejecución del proyecto:
* **Tener maquina EC2 en AWS**
  - tipo t2.large con 40 GB DD
  - asignarle una IP flotante para que la VM tenga siempre la misma IP pública
  - abrir los puertos 5050 y 5432 desde diferentes subredes privadas, Internet, etc
* **Instalar Docker en Ubuntu 24.04**
https://docs.docker.com/engine/install/ubuntu/
* **Agregar usuario ubuntu como ejecutante**
  - sudo usermod -a -G docker ubuntu
* **Clonar repositorios**
  - git clone https://github.com/si3009eafit/si3009-261.git
  - git clone https://github.com/CesarMontoyag1/Bases-de-datos-avanzadas.git
* **Establecer tunel entre máquina y EC"**
  - ssh -i "file.pem" ubuntu@ip-publica -L 5050:<ip-privada-ec2>:5050
* **Lanzar postgres y pgAdmin**
  - cd si3009-261/pg-lab1
  - docker compose up -d
* **Conectarse a pgAdmin**
