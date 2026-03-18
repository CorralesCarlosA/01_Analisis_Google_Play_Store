"""Limpieza y transformación de Google Play Store usando pandas

Este script replica el pipeline SQL en Python con pasos explicados
para que puedas aprender y estudiar cada etapa.
"""

import pandas as pd
import numpy as np
import os

# 1) Cargar datos
csv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'DATA', 'googleplaystore.csv'))
print('Ruta CSV:', csv_path)

df = pd.read_csv(csv_path)
print('Filas cargadas:', len(df))
print('Columnas:', list(df.columns))

# 2) Mostrar ejemplos iniciales para entender problemas
print('\nPrimeras 5 filas (raw):')
print(df.head())
print('\nValores faltantes por columna (raw):')
print(df.isna().sum())

# 3) Crear una copia para el pipeline de limpieza
apps = df.copy()

# 4) Normalizar nombres de columnas (sin espacios ni mayúsculas) para análisis más cómodo
apps.columns = [col.strip().lower().replace(' ', '_').replace('-', '_') for col in apps.columns]
print('\nColumnas normalizadas:', apps.columns.tolist())

# 5) Convertir rating a numérico
# Si hay texto inválido, quedará NaN
apps['rating'] = pd.to_numeric(apps['rating'], errors='coerce')

# 6) Limpiar reviews: convertir a entero
apps['reviews'] = pd.to_numeric(apps['reviews'], errors='coerce').astype('Int64')

# 7) Normalizar size -> bytes
# Explicación: 19M -> 19000000, 103k -> 103000, 'Varies with device' -> NaN

def parse_size(size):
    if pd.isna(size):
        return np.nan
    s = str(size).strip()
    if s == '' or s.lower() == 'varies with device':
        return np.nan
    # Reemplazar posibles comas y espacios
    s = s.replace(',', '').replace(' ', '')
    try:
        if s[-1] in ['M', 'm']:
            return float(s[:-1]) * 1_000_000
        if s[-1] in ['K', 'k']:
            return float(s[:-1]) * 1_000
        # Si es valor numérico puro o 19 (sin unidad)
        return float(s)
    except Exception:
        return np.nan

apps['size_bytes'] = apps['size'].apply(parse_size)

# Rellenar valores faltantes con la media de los valores válidos (como hace SQL)
mean_size = apps['size_bytes'].mean(skipna=True)
apps['size_bytes'] = apps['size_bytes'].fillna(mean_size)

# 8) Limpiar installs -> entero
# El CSV usa formato como 1,000,000+, 500+, etc.
apps['installs'] = apps['installs'].astype(str).str.replace('[+,]', '', regex=True)
apps['installs'] = pd.to_numeric(apps['installs'], errors='coerce').astype('Int64')

# 9) Limpiar price -> float
apps['price'] = apps['price'].astype(str).str.replace('[$]', '', regex=True).replace('Free', '0', regex=False)
apps['price'] = pd.to_numeric(apps['price'], errors='coerce').fillna(0.0)

# 10) Mapear content_rating a numérico
content_map = {
    'Everyone': 1,
    'Everyone 10+': 2,
    'Teen': 3,
    'Mature 17+': 4,
    'Adults only 18+': 5,
    'Unrated': 0,
    np.nan: 0,
    '': 0,
}
apps['content_rating_normalized'] = apps['content_rating'].astype(str).str.strip().replace({'nan': ''})
apps['content_rating_numeric'] = apps['content_rating_normalized'].map(content_map).fillna(0).astype(int)

# 11) Mapear type a numérico
apps['type_normalized'] = apps['type'].astype(str).str.strip().str.title()
apps['type_numeric'] = apps['type_normalized'].map({'Free': 0, 'Paid': 1}).fillna(0).astype(int)

# 12) Convertir última actualización a fecha
apps['last_updated'] = pd.to_datetime(apps['last_updated'], errors='coerce')

# 13) Android version parsea la parte numérica mayor
# Ejemplo: '4.0 and up' -> 4.0

def parse_android_version(v):
    if pd.isna(v):
        return np.nan
    s = str(v).strip().lower()
    if s == '' or s == 'varies with device':
        return np.nan
    # Tomar primer número que aparezca
    import re
    m = re.search(r'\d+(\.\d+)?', s)
    if m:
        return float(m.group(0))
    return np.nan

apps['android_version_float'] = apps['android_ver'].apply(parse_android_version)

# 14) Funciones de validación de calidad de datos (COMENTARIO PARA ESTUDIAR)
# Estas funciones permiten obtener métricas y detectar problemas antes de guardar.

def data_quality_report(df):
    # Completeness: porcentaje de valores no nulos por columna
    completeness = (1 - df.isna().mean()) * 100
    # Duplicados: filas exactamente iguales
    duplicate_rows = df.duplicated().sum()
    # Valores únicos por columnas clave
    unique_values = {col: int(df[col].nunique(dropna=False)) for col in ['app', 'category', 'content_rating', 'type'] if col in df.columns}
    # Rango de fechas
    date_min = df['last_updated'].min() if 'last_updated' in df.columns else None
    date_max = df['last_updated'].max() if 'last_updated' in df.columns else None
    return {
        'completeness_pct': completeness.round(2).to_dict(),
        'duplicate_rows': int(duplicate_rows),
        'unique_values': unique_values,
        'last_updated_min': date_min,
        'last_updated_max': date_max,
    }


def validate_columns(df):
    # Validaciones básicas que pueden guardarse en logs
    checks = {
        'app_not_null_pct': float(df['app'].notna().mean() * 100),
        'rating_range': (float(df['rating'].min(skipna=True)), float(df['rating'].max(skipna=True))),
        'installs_non_negative_pct': float((df['installs'] >= 0).mean() * 100),
        'size_bytes_positive_pct': float((df['size_bytes'] > 0).mean() * 100),
        'price_non_negative_pct': float((df['price'] >= 0).mean() * 100),
    }
    return checks


# Marcar filas no válidas: app vacío o nombre 'App' (encabezado repetido)
apps['is_valid'] = True
apps.loc[apps['app'].isna() | (apps['app'].str.strip() == ''), 'is_valid'] = False
apps.loc[apps['app'].str.strip().str.lower() == 'app', 'is_valid'] = False

# 15) Detección y eliminación de duplicados por nombre + categoria
apps['app_lower'] = apps['app'].astype(str).str.lower().str.strip()
apps['category_lower'] = apps['category'].astype(str).str.lower().str.strip()
dups = apps.duplicated(subset=['app_lower', 'category_lower'], keep='first')
apps['is_duplicate'] = dups
apps = apps[~apps['is_duplicate']].copy()

# 16) Reportes de calidad de datos
quality_report = data_quality_report(apps)
validation_checks = validate_columns(apps)

print('\n==== REPORTES DE CALIDAD DE DATOS (COMENTARIO PARA ESTUDIAR) ====')
print('Completeness (%) por columna:')
for col, pct in quality_report['completeness_pct'].items():
    print(f'  - {col}: {pct:.2f}%')
print('Filas duplicadas encontradas:', quality_report['duplicate_rows'])
print('Valores únicos clave:', quality_report['unique_values'])
print('Rango de fecha last_updated:', quality_report['last_updated_min'], '->', quality_report['last_updated_max'])
print('Validaciones agregadas:')
for key, value in validation_checks.items():
    print(f'  - {key}: {value}')

# 17) Informes de calidad de datos y limpieza final
print('\nResumen de calidad de datos después de limpieza:')
print('Total filas (después de duplicados):', len(apps))
print('Filas válidas:', apps['is_valid'].sum())
print('Filas inválidas:', (~apps['is_valid']).sum())
print('Valores nulos por columna clave:')
print(apps[['rating','reviews','size_bytes','installs','price','content_rating_numeric','type_numeric','last_updated','android_version_float']].isna().sum())

# 18) Mostrar primeras filas limpias
print('\nMuestra de datos limpios:')
print(apps[['app','category','rating','reviews','size_bytes','installs','price','content_rating','content_rating_numeric','type','type_numeric','last_updated','android_ver','android_version_float']].head(10))

# 18) Guardar output limpio para análisis futuro
out_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'DATA', 'googleplaystore_cleaned.csv'))
apps.to_csv(out_path, index=False)
print('\nArchivo limpio guardado en:', out_path)

# 19) Estadísticas finales para compartir con el usuario
print('\nEstadísticas finales resumidas:')
print('Rating promedio:', apps['rating'].mean(skipna=True))
print('Installs promedio:', apps['installs'].mean(skipna=True))
print('Tamaño promedio (MB):', apps['size_bytes'].mean(skipna=True) / 1_000_000)
print('Porcentaje apps de pago:', 100 * (apps['type_numeric'] == 1).mean())
