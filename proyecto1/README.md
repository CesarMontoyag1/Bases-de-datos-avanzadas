# Proyecto 1: Caso de estudio Optimización de Bases de Datos y Big Data

## Objetivo del Trabajo
Aplicar técnicas avanzadas de optimización de consultas, particionamiento, índices y *performance tuning* a nivel de servidor (PostgreSQL) sobre una base de datos con un esquema OLTP estilo e-commerce escalada a más de 30 millones de registros. 

## Estructura del Directorio

* `/scripts/`: Contiene los archivos SQL para crear el esquema, generar los datos y aplicar las optimizaciones.
* `/docker/`: Archivos `docker-compose.yml` y configuraciones (`postgresql.conf`) para levantar la instancia local o en EC2.
* `/docs/`: Contiene el informe técnico final en formato PDF.
* `README.md`: Este archivo de documentación.

## Arquitectura y Entorno Tecnológico

Las pruebas y mediciones se realizaron en dos entornos distintos para comparar rendimientos:
1. **AWS EC2 (Dockerizado):** Instancia Ubuntu corriendo PostgreSQL en un contenedor Docker con parámetros de memoria ajustados manualmente.
2. **AWS RDS:** Base de datos gestionada por Amazon Web Services, utilizando *Parameter Groups* para el *tuning*.

