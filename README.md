# Bases de Datos Avanzadas - Universidad EAFIT

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)

Bienvenido al repositorio oficial del curso **Bases de Datos Avanzadas** (2026) de la Universidad EAFIT. 
Este espacio documenta y almacena todos los proyectos prácticos, scripts y análisis desarrollados a lo largo del semestre académico en la trayectoria de Ingeniería de Datos.

## Equipo de Trabajo

* **Cesar Montoya Giraldo** - [CesarMontoyag1](https://github.com/CesarMontoyag1)
* **Juan Pablo Corena** - [JP-2112](https://github.com/JP-2112)

**Docente:** Edwin Montoya Múnera

---

## Proyectos del Curso

A continuación, se presenta el listado de proyectos desarrollados. Cada carpeta contiene su propia documentación detallada para la replicación de los entornos y los informes técnicos correspondientes.

| Proyecto | Descripción | Estado | Enlace |
| :--- | :--- | :---: | :--- |
| **Proyecto 1** | Caso de estudio Optimización, Performance Tuning y manejo de Big Data (30M+ registros). | Completado | [Ir al Proyecto 1](./proyecto1/) |
| **Proyecto 2** | - | Pendiente | - |


---

## **Proyecto 1:** 
### Tecnologías Utilizadas:
* **Motor de Base de Datos:** PostgreSQL
* **Infraestructura:** AWS EC2, AWS RDS
* **Contenedores:** Docker & Docker Compose
* **Herramientas de Análisis:** EXPLAIN ANALYZE, PgAdmin / DBeaver

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
  - http://localhost:5050 ó http://<ip_publica_EC2:5050
  - usuario: user@acme.com y clave: adminpass

> **Nota:** Este repositorio está diseñado bajo prácticas de DevOps para facilitar la lectura y replicación de los laboratorios por parte del equipo docente y otros desarrolladores.
