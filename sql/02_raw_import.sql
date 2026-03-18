/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 02_raw_import.sql
BASE DE DATOS: google_play

DESCRIPCION:
Este script importa el archivo CSV original a una tabla
de staging sin transformación.

Se utiliza una estrategia RAW para evitar fallos
causados por datos corruptos o filas mal formateadas.

Esta técnica es estándar en procesos ETL profesionales y la que uso usualmente para la mayoria de mis operaciones.
==========================================================
*/

-- Verificar que estamos en la base correcta
SELECT current_database();

/*****************************************************
FASE 1: LIMPIEZA PREVIA (SI ES NECESARIO)
*****************************************************/

-- Vaciar tabla si ya tenía datos anteriores
TRUNCATE TABLE staging_apps_raw;

/*****************************************************
FASE 2: IMPORTACION DEL ARCHIVO
*****************************************************/

-- Importar cada fila como texto completo
COPY staging_apps_raw
FROM 'D:\ANALISIS DE DATOS\AnalisisDatos\Portafolio\01_Analisis_Rendimiento_SQL\data\googleplaystore.csv';
-- precausion: para hacer prubas, descargar la base de datos y usar la direccion correspondiente a su maquina.

/*****************************************************
FASE 3: VALIDACION DE CARGA
*****************************************************/

-- Contar registros importados
SELECT COUNT(*) AS total_rows_loaded FROM staging_apps_raw;

-- Visualizar muestra inicial
SELECT * FROM staging_apps_raw LIMIT 5;

--Esta etapa de validacion solo es para verificar que efectivamente el metodo raw halla funcinado.