/*
==========================================================
PROYECTO: Google Play Store Analysis
ARCHIVO: 06_clean_content_rating_and_type.sql

PROPÓSITO: Limpiar y normalizar categorías de audiencia
y tipo de aplicación

DESCRIPCIÓN:
Estos scripts manejan dos opciones:

OPCIÓN 1: CONTENT_RATING
  Valores actuales: Everyone, Everyone 10+, Teen, Mature 17+, Adults only 18+, Unrated
  Se mapean a valores numéricos para análisis

OPCIÓN 2: TYPE (¿Es esto lo que quisiste?)
  Valores actuales: Free, Paid
  Se mapean a 0 (Free) y 1 (Paid)

Realiza las siguientes transformaciones:
1. Normalizar valores (eliminar espacios extra)
2. Mapear a valores numéricos
3. Manejar valores nulos o inválidos
4. Crear tabla de referencia para auditoría

==========================================================
*/

-- Verificar base de datos activa
SELECT CURRENT_DATABASE();


/*****************************************************
FASE 1: ANÁLISIS PREVIO
*****************************************************/

-- Explorar valores únicos en Content Rating
SELECT COUNT(*) AS count, 'Content Rating' AS analysis, content_rating AS value
FROM staging_apps
WHERE content_rating IS NOT NULL
GROUP BY content_rating
ORDER BY count DESC;

-- Explorar valores únicos en Type (si existe)
SELECT COUNT(*) AS count, 'Type' AS analysis, type AS value
FROM staging_apps
WHERE type IS NOT NULL
GROUP BY type
ORDER BY count DESC;


/*****************************************************
FASE 2: CREAR TABLAS DE MAPEO (LOOKUP TABLES)
*****************************************************/

-- Tabla de mapeo para Content Rating
DROP TABLE IF EXISTS mapping_content_rating CASCADE;

CREATE TABLE mapping_content_rating (
    content_rating_original TEXT PRIMARY KEY,
    content_rating_numeric INT,
    severity_level TEXT,
    description TEXT
);

INSERT INTO mapping_content_rating (content_rating_original, content_rating_numeric, severity_level, description) VALUES
    ('Everyone', 1, 'LOWEST', 'Contenido para todas las edades'),
    ('Everyone 10+', 2, 'LOW', 'Contenido para mayores de 10 años'),
    ('Teen', 3, 'MEDIUM', 'Contenido para adolescentes'),
    ('Mature 17+', 4, 'HIGH', 'Contenido para mayores de 17 años'),
    ('Adults only 18+', 5, 'HIGHEST', 'Solo para adultos'),
    ('Unrated', 0, 'UNKNOWN', 'Sin clasificación'),
    ('', 0, 'UNKNOWN', 'Valor vacío'),
    (NULL, 0, 'UNKNOWN', 'Valor nulo');

SELECT 'Tabla mapping_content_rating creada' AS status;


-- Tabla de mapeo para Type (Free/Paid)
DROP TABLE IF EXISTS mapping_app_type CASCADE;

CREATE TABLE mapping_app_type (
    type_original TEXT PRIMARY KEY,
    type_numeric INT,
    type_name TEXT,
    description TEXT
);

CREATE TABLE  mapping_app_type
INSERT INTO mapping_app_type (type_original, type_numeric, type_name, description) VALUES
    ('Free', 0, 'GRATUITA', 'Aplicación gratuita'),
    ('Paid', 1, 'DE_PAGO', 'Aplicación de pago'),
    ('', 0, 'UNKNOWN', 'Valor vacío - asumida como Free'),
    (NULL, 0, 'UNKNOWN', 'Valor nulo - asumida como Free');

SELECT 'Tabla mapping_app_type creada' AS status;


/*****************************************************
FASE 3: CREAR FUNCIONES DE NORMALIZACIÓN
*****************************************************/

-- Función para convertir Content Rating a numérico
CREATE OR REPLACE FUNCTION normalize_content_rating(p_content_rating TEXT)
RETURNS INT AS $$
DECLARE
    v_cleaned TEXT;
BEGIN
    IF p_content_rating IS NULL THEN
        RETURN 0;
    END IF;

    v_cleaned := TRIM(p_content_rating);

    IF v_cleaned = '' THEN
        RETURN 0;
    END IF;

    -- Buscar en la tabla de mapeo
    SELECT content_rating_numeric INTO v_cleaned
    FROM mapping_content_rating
    WHERE UPPER(TRIM(content_rating_original)) = UPPER(v_cleaned)
    LIMIT 1;

    -- Si no encuentra coincidencia, retornar 0 (desconocido)
    RETURN COALESCE(v_cleaned::INT, 0);

EXCEPTION WHEN OTHERS THEN
    RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT 'Función normalize_content_rating creada' AS status;


-- Función para convertir Type (Free/Paid) a numérico
CREATE OR REPLACE FUNCTION normalize_app_type(p_type TEXT)
RETURNS INT AS $$
DECLARE
    v_cleaned TEXT;
    v_result INT;
BEGIN
    IF p_type IS NULL THEN
        RETURN 0;  -- NULL se considera Free
    END IF;

    v_cleaned := TRIM(p_type);

    IF v_cleaned = '' THEN
        RETURN 0;  -- Vacío se considera Free
    END IF;

    -- Buscar en la tabla de mapeo
    SELECT type_numeric INTO v_result
    FROM mapping_app_type
    WHERE UPPER(TRIM(type_original)) = UPPER(v_cleaned)
    LIMIT 1;

    -- Si no encuentra coincidencia, retornar 0 (gratuita)
    RETURN COALESCE(v_result, 0);

EXCEPTION WHEN OTHERS THEN
    RETURN 0;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

SELECT 'Función normalize_app_type creada' AS status;


/*****************************************************
FASE 4: ACTUALIZAR TABLA CLEAN_APPS CON NUEVAS COLUMNAS
*****************************************************/

-- Agregar columnas numéricas si no existen
ALTER TABLE clean_apps
ADD COLUMN IF NOT EXISTS content_rating_numeric INT,
ADD COLUMN IF NOT EXISTS type_numeric INT;

-- Actualizar valores de content_rating_numeric
UPDATE clean_apps
SET content_rating_numeric = normalize_content_rating(
    (SELECT content_rating FROM staging_apps WHERE staging_apps.app_id = clean_apps.app_id)
);

-- Actualizar valores de type_numeric
UPDATE clean_apps
SET type_numeric = normalize_app_type(
    (SELECT type FROM staging_apps WHERE staging_apps.app_id = clean_apps.app_id)
);

SELECT 'Columnas numéricas agregadas y actualizadas' AS status;


/*****************************************************
FASE 5: VALIDEZ ESTADÍSTICAS
*****************************************************/

-- Estadísticas de Content Rating
SELECT
    'CONTENT_RATING' AS columna,
    COUNT(*) AS total_rows,
    COUNT(content_rating_numeric) AS non_null_values,
    COUNT(CASE WHEN content_rating_numeric = 0 THEN 1 END) AS unknown_or_null,
    COUNT(CASE WHEN content_rating_numeric = 1 THEN 1 END) AS everyone,
    COUNT(CASE WHEN content_rating_numeric = 2 THEN 1 END) AS everyone_10plus,
    COUNT(CASE WHEN content_rating_numeric = 3 THEN 1 END) AS teen,
    COUNT(CASE WHEN content_rating_numeric = 4 THEN 1 END) AS mature_17plus,
    COUNT(CASE WHEN content_rating_numeric = 5 THEN 1 END) AS adults_only
FROM clean_apps;

-- Estadísticas de Type
SELECT
    'APP_TYPE' AS columna,
    COUNT(*) AS total_rows,
    COUNT(type_numeric) AS non_null_values,
    COUNT(CASE WHEN type_numeric = 0 THEN 1 END) AS free_apps,
    COUNT(CASE WHEN type_numeric = 1 THEN 1 END) AS paid_apps
FROM clean_apps;


/*****************************************************
FASE 6: EJEMPLOS DE TRANSFORMACIÓN
*****************************************************/

-- Mostrar ejemplos de las transformaciones realizadas
SELECT
    app_name,
    content_rating,
    content_rating_numeric,
    type,
    type_numeric
FROM clean_apps
LIMIT 20;

-- Verificar distribución de valores normalizados
SELECT
    'Content Rating' AS metric,
    content_rating_numeric AS valor,
    COUNT(*) AS cantidad
FROM clean_apps
GROUP BY content_rating_numeric
ORDER BY valor
UNION ALL
SELECT
    'App Type' AS metric,
    type_numeric AS valor,
    COUNT(*) AS cantidad
FROM clean_apps
GROUP BY type_numeric
ORDER BY valor;

SELECT 'Validación completada' AS status;
