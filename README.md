# Análisis Google Play Store - Pipeline ETL en SQL

Pipeline de limpieza y transformación de datos usando PostgreSQL y SQL para normalizar 130,000+ aplicaciones de Google Play Store.

## Objetivo

Implementar un pipeline ETL profesional que:
- Importa datos crudos de Google Play Store (googleplaystore.csv)
- Estructura y valida la información
- Normaliza columnas problemáticas (size, content_rating, type)
- Prepara datos limpios para análisis avanzados

## Transformaciones Realizadas

### 1. Normalización de SIZE (Columna de Tamaño)

Convierte valores múltiples formatos a bytes en formato FLOAT:
- 19M → 19,000,000 bytes
- 103k → 103,000 bytes
- Valores faltantes: rellenados con promedio calculado
- Resultado: FLOAT estandarizado

### 2. Mapeo de CONTENT_RATING (Calificación de Contenido)

Conversión a escala numérica:
- Everyone = 1
- Everyone 10+ = 2
- Teen = 3
- Mature 17+ = 4
- Adults only 18+ = 5
- Unrated/NULL = 0

### 3. Conversión de TYPE (Tipo de Aplicación)

Mapeo a valores binarios:
- Free = 0
- Paid = 1

## Estructura del Proyecto

```
01_Analisis_Google_Play_Store/
├── README.md                    (Este archivo)
├── GUIA_RAPIDA.md              (Guía de inicio rápido)
├── data/
│   └── googleplaystore.csv      (130K+ registros originales)
├── sql/
│   ├── MASTER_PIPELINE.sql       (Script principal - ejecuta todo)
    ├── 00_enhanced_database_setup.sql
│   ├── 01_improved_import.sql
│   ├── 02_structured_staging.sql
│   ├── 05_clean_size_column.sql
│   ├── 06_clean_content_rating_and_type.sql
│   ├── README.md                (Documentación detallada)
│   └── ESPECIFICACIONES_TECNICAS.md (Detalles técnicos)
└── Python/
    └── (Análisis avanzado - futuro)
```

## Ejecución Rápida

### Opción 1: Ejecución Completa (Recomendado)

1. Abre DBeaver u otro cliente SQL PostgreSQL
2. Selecciona la base de datos google_play
3. Abre: sql/MASTER_PIPELINE.sql
4. Ejecuta todo el script (Ctrl+Enter)
5. Tiempo estimado: 2-5 minutos

### Opción 2: Ejecución Paso a Paso

1. sql/01_improved_import.sql (importa CSV)
2. sql/02_structured_staging.sql (estructura datos)
3. sql/05_clean_size_column.sql (normaliza SIZE)
4. sql/06_clean_content_rating_and_type.sql (mapea CONTENT_RATING y TYPE)

## Verificación

Después de ejecutar el pipeline:

```sql
-- Ver tabla limpia
SELECT app_name, size, content_rating_numeric, type_numeric 
FROM clean_apps 
LIMIT 20;

-- Estadísticas de calidad
SELECT 
    COUNT(*) AS total_apps,
    ROUND(AVG(size)/1000000, 2) AS avg_size_mb,
    COUNT(CASE WHEN content_rating_numeric > 0 THEN 1 END) AS rated_apps
FROM clean_apps;
```

## Documentación

| Archivo | Descripción |
|---------|-------------|
| GUIA_RAPIDA.md | Explicación visual del proyecto y transformaciones |
| sql/README.md | Guía completa de ejecución paso a paso |
| sql/ESPECIFICACIONES_TECNICAS.md | Detalles técnicos de todas las transformaciones |
| sql/MASTER_PIPELINE.sql | Script principal integrado |

## Tecnologías

- PostgreSQL - Base de datos relacional
- SQL - Lenguaje de consulta y ETL
- DBeaver - Cliente SQL
- Python - (Futuro) Análisis avanzado

## Resultados Finales

Al ejecutar el pipeline se obtiene:
- Tabla clean_apps completamente normalizada
- Datos estructurados listos para análisis exploratorio (EDA)
- Métricas de calidad de datos validadas
- Documentación completa de transformaciones

---

Creado: Marzo 2026 | Estado: Producción
