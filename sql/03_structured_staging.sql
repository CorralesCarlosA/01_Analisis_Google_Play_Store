/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 03_structured_staging.sql
BASE DE DATOS: google_play

DESCRIPCION:
Transforma los datos crudos almacenados como texto
en una estructura tabular organizada por columnas.

Se excluye la fila de encabezado.
==========================================================
*/

-- Verificar base activa
SELECT current_database();


/*****************************************************
FASE 1: CREAR TABLA STAGING ESTRUCTURADA
*****************************************************/
-- Tratar de eliminar en caso que la tabla ya exista
DROP TABLE IF EXISTS staging_apps;

-- Crear la base de datos con los nombres de las columnas y las caracteristicas que tienen la base de datos de entrada
CREATE TABLE staging_apps (
    app_name TEXT,
    category TEXT,
    rating TEXT,
    reviews TEXT,
    size TEXT,
    installs TEXT,
    type TEXT,
    price TEXT,
    content_rating TEXT,
    genres TEXT,
    last_updated TEXT,
    current_version TEXT,
    android_version TEXT
);


/*****************************************************
FASE 2: INSERTAR DATOS TRANSFORMADOS
*****************************************************/

INSERT INTO staging_apps
SELECT
    (string_to_array(raw_line, ','))[1] as app_name,
    (string_to_array(raw_line, ','))[2] as rating,
    (string_to_array(raw_line, ','))[3] as category,
    (string_to_array(raw_line, ','))[4] as reviews,
    (string_to_array(raw_line, ','))[5] as size,
    (string_to_array(raw_line, ','))[6] as installs,
    (string_to_array(raw_line, ','))[7] as type,
    (string_to_array(raw_line, ','))[8] as price,
    (string_to_array(raw_line, ','))[9] as content_rating,
    (string_to_array(raw_line, ','))[10] as genres,
    (string_to_array(raw_line, ','))[11] as last_updated,
    (string_to_array(raw_line, ','))[12] as current_version,
    (string_to_array(raw_line, ','))[13] as android_version
FROM staging_apps_raw
WHERE raw_line NOT LIKE 'App,%';


/*****************************************************
FASE 3: VALIDACION DE INTEFRIDAD Y EXPLORACION INICIAL
Esta fase permite verificar que los datos se cargaron correctamente
antes de proceder a la limpieza y analisis.
*****************************************************/

-- Verificar cantidad de registros
SELECT COUNT(*) AS total_registros
FROM staging_apps;

-- Visualizar muestra
SELECT *
FROM staging_apps
LIMIT 5;
/*se puede ver que tenemos el total de registros reales de la base de datos original,
lo que indica que el metodo de carga raw fue un exito.
*/
SELECT COUNT(*) FROM staging_apps_raw;
--esto se hace solo para verificar el numero de registros que tiene  la tabla con datos sin procesar.

SELECT *
FROM staging_apps
WHERE category LIKE '%GAME%';
-- No es necesario para la investigacion, pero quise hacerlo a modo de practica para ver el filtrado con LIKE.

/*
EXPLORACIÓN DE DATOS:
Esta sección valida los datos estructurados y explora su integridad antes de limpiarlos y transformarlos.
Este es un paso crucial en cualquier canalización de datos del mundo real.
*/

--se usa DISTINCT    para ver las categorias unicas, y se ordena alfabeticamente para facilitar la lectura con ORDER BY.
SELECT distinct category from staging_apps order by category