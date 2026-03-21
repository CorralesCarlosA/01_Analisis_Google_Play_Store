# Reporte Completo: Análisis y Limpieza de Google Play Store

## 1) Objetivo del proyecto

Este reporte describe paso a paso el pipeline ETL aplicado sobre el dataset `googleplaystore.csv` y la lógica de limpieza/validación en SQL y Python. El objetivo es:

- Crear una base de datos limpia para análisis y modelado.
- Documentar cada transformación con justificación técnica para reclutadores.
- Generar indicadores de calidad de datos (data quality metrics).
- Mostrar visualizaciones y decisiones explícitas.

---

## 2) Estructura del proyecto

Carpeta principal: `CDataEngineering`

- `sql/`: scripts del pipeline original SQL.
- `Python/clean_google_play.py`: pipeline Python de transformación y validación.
- `Python/GooglePlay_Study.ipynb`: notebook de estudio con ETL, EDA y modelo.
- `DATA/googleplaystore_cleaned.csv`: dataset limpio generado.

---

## 3) Diagnóstico inicial de los scripts SQL

En `sql/MASTER_PIPELINE.sql` y archivos relacionados se detectaron:

1. Importación con `COPY` dependiente de rutas locales absolutas.
2. Parsing CSV con `string_to_array(..., ',')` que no maneja comillas/comas en texto.
3. Transformaciones de `size`, `content_rating` y `type` definidas en funciones SQL.
4. Generación de tabla `clean_apps` eventual.

### Problemas encontrados

- El `COPY` original tenía errores de sintaxis (falta paréntesis). 
- El parser SQL es frágil para CSV con comas internas.
- Valores inconsistentes (e.g., `Size = 'Varies with device'`, `rating` nulos, `android_ver` en texto).

---

## 4) Implementación Python (paso a paso)

### 4.1 Carga de datos

Usamos pandas para leer CSV: `pd.read_csv(DATA/googleplaystore.csv)`.
Ventaja: pandas maneja correctamente comillas y codificación.

### 4.2 Normalización de columnas

Renombramos columnas a minúsculas y `_` para consistencia y reproducibilidad.

### 4.3 Conversión de tipos

- `rating` → numérico (`pd.to_numeric(errors='coerce')`) permitiendo NaN en datos inválidos.
- `reviews` → entero.
- `installs` → quitar signos `+` y comas, convertir a entero.
- `price` → quitar `$` y convertir a flotante.

### 4.4 Limpieza de `size`

Función `parse_size`:
- `19M` → multiplicar por 1,000,000
- `103k` → multiplicar por 1,000
- `Varies with device` / vacíos → NaN
- NaN rellenar con media de tamaño válido

Justificación: normalizamos a bytes para comparar y analizar magnitudes de tamaño de app. Se elige esta fórmula porque la fuente usa unidades M/k variables.

### 4.5 Normalización de etiquetas categóricas

- `content_rating` mapeada a valores numéricos: `Everyone=1`, `Teen=3`, `Adults only 18+=5`, `Unrated=0`.
- `type` mapeada a `Free=0`, `Paid=1`.

Justificación: Convertir categorías a numéricos permite análisis cuantitativo y modelado.

### 4.6 Fechas y versión de Android

- Convertimos `last_updated` con `pd.to_datetime`.
- Extraemos primer número de `android_ver` con regex para `android_version_float`.

### 4.7 Validación de filas

Se marcan filas inválidas:
- App nulo o vacío
- Fila de encabezado repetida (`App`)
Duplicados eliminados por `app + category`.

### 4.8 Data Quality Metrics (funciones de validación)

Se agregaron funciones:
- `quality_report(df)` → valores faltantes %, duplicados, valores únicos.
- `validate_columns(df)` → rangos de `rating`, no-negatividad de `installs`, `size_bytes`, `price`.

Siempre se imprime con mensaje didáctico (COMENTARIO PARA ESTUDIAR).

---

## 5) Análisis exploratorio y visualizaciones

En el notebook usamos gráficos seleccionados con razones claras:

1. Histograma de `rating`:
   - Permite ver sesgo de valoraciones y detectar valores extremos.
   - Se eligió histogramas en lugar de barras para variable continua.

2. Histograma de `size_bytes` (MB):
   - Muestra la distribución de tamaños de app; se toma en MB para intérprete humano.
   - Se elige histograma con KDE para evaluar densidad y colas.

3. Mapa de calor de correlaciones:
   - Identifica relaciones entre variables numéricas antes de modelar.
   - Se elige heatmap con anotaciones por claridad.

4. Scatter plot / boxplot (opcional en notebook) para comparar `rating` vs `price`, `installs`.
   - Explica por qué seleccionamos variables: detectar si precio correlaciona con rating.

### Por qué estas visualizaciones y no otras

- Se priorizó interpretabilidad (histogramas + correlaciones) para reclutadores.
- No se usaron gráficas 3D o demasiado complejas porque el objetivo es claridad y narrativa de calidad de datos.
- Elegimos EDA clásico para mostrar control de limpieza y entender tendencias.

---

## 6) Modelo predictivo simple y métricas

Usamos regresión lineal para predecir `rating` a partir de:
- `size_bytes`
- `installs`
- `content_rating_num`
- `type_num`

Métricas generadas:
- RMSE (error promedio)
- R2 (proporción de varianza explicada)

Justificación: modelo sencillo para mostrar que el dataset limpio es apto para ML y para evaluar calidad en un pipeline de datos.

---

## 7) Resultados de calidad de datos (finales)

Desde la ejecución de Python, estas métricas se reportan:

- Total filas limpio: 9,731
- Filas inválidas: 0 (tras validación y eliminación de encabezado)
- Nulos en variables clave:
  - `rating`: 1,460
  - `reviews`: 1
  - `installs`: 1
  - `android_version_float`: 1,008

Esto indica que la calidad es alta en columnas críticas, con datos faltantes esperables en rating.

---

## 8) Archivos generados y cómo presentar a reclutadores

1. Archivo limpio generado: `DATA/googleplaystore_cleaned.csv`
2. Script reproducible: `Python/clean_google_play.py` (comentado para estudiar)
3. Notebook para presentar: `Python/GooglePlay_Study.ipynb` con 
   - carga
   - limpieza
   - validación
   - EDA
   - modelo
   - conclusiones
4. Recomendación para CV/reclutadores: incluir sección "Data Quality & ETL" con métricas y gráficos clave.

---

## 9) Conclusiones y próximos pasos recomendados

- El pipeline SQL original es funcional, pero el pipeline Python es más robusto para CSV.
- Se lograron datos limpios listos para análisis con metodologías replicables.
- Para reforzar aún más la presentación, agrega un notebook final estilo "slide" con hallazgos clave, calidad y visualizaciones.

### Próximos pasos técnicos

1. Agregar pruebas unitarias para funciones de validación (`parse_size`, mapeos).
2. Ejecutar pipeline completo en un script `run_etl.py` con logs.
3. Crear un dashboard mínimo en Streamlit o PowerBI usando el CSV limpio.

---

## 10) Anexo: Instrucciones para ejecutar de nuevo

1. Activa el entorno:
   - `env\Scripts\activate` (Windows)
2. Ejecuta limpieza:
   - `python Python\clean_google_play.py`
3. Ejecuta notebook (opcional):
   - `python -m jupyter notebook Python\GooglePlay_Study.ipynb`
4. Abre `DATA/googleplaystore_cleaned.csv` para validación final.

---

> Nota: Este reporte está listo para usar como documento de entrega a reclutadores. Incluye Justificaciones, decisiones de visualización y métricas de calidad de datos para demostrar dominio en análisis de datos.
