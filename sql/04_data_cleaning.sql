/*****************************************************
DOCUMENTO 04 - DATA CLEANING
En esta fase convertimos los datos estructurados
a tipos adecuados para análisis.
No se modifica staging_apps.
Se crea una nueva tabla limpia.
*****************************************************/
 
select * from staging_apps ; -- obervo todos los datos que hay sin limitaicones


DROP TABLE IF EXISTS clean_apps; -- elimino la tabla limpia por si ya existe, para evitar errores al crearla de nuevo

CREATE TABLE clean_apps AS
SELECT
app_name,
category,

CASE
    WHEN rating ~ '^[0-9]+(\.[0-9]+)?$'
    THEN rating::double precision
    ELSE NULL
END AS rating,

size,

NULLIF(
    regexp_replace(installs, '[^0-9]+', '', 'g'),
    ''
)::bigint AS installs,

NULLIF(
    regexp_replace(price, '[^0-9.]', '', 'g'),
    ''
)::double precision AS price,

content_rating,
genres,

CASE 
    WHEN last_updated ~ '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
    THEN to_date(last_updated, 'Month DD, YYYY')
    ELSE NULL
END AS last_updated,

current_version,
android_version

FROM staging_apps
WHERE category !~ '^[0-9]';


-- elimina la fila corrupta


SELECT installs
FROM staging_apps where installs !~ '^[0-9,+]+$';

/* Al tratar de crear la tabla me encontre con varios errres en la informacion
1. N

*/ 


SELECT * FROM clean_apps;



SELECT
    COUNT(*) AS total_registros,

    COUNT(*) FILTER (
        WHERE last_updated ~ '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
    ) AS fechas_validas,
    COUNT(*) FILTER (
        WHERE last_updated !~ '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
    ) AS fechas_invalidas,
    (COUNT(*) FILTER (
        WHERE last_updated !~ '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
    ) * 100.0) / COUNT(*) AS fechas_invalidas_porcentaje,
    COUNT(*) FILTER (
        WHERE last_updated ~ '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$'
    ) * 100.0 / COUNT(*)AS fechas_validas_porcentaje
FROM staging_apps;

SELECT last_updated, COUNT(last_updated) FROM staging_apps group by last_updated;


select * from clean_apps;