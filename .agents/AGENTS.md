# Reglas del Proyecto SweetStock

## Arquitectura del Ecosistema

El proyecto SweetStock está compuesto por **dos aplicaciones** que operan de forma
sincrónica sobre la misma base de datos Firebase Firestore (proyecto: `sweetstock-app-fase3`):

- **sweetstock_app** — App móvil Flutter/Android
  Repositorio: https://github.com/yhobany/sweetstock_app
  Ruta local: `C:\Users\angel\sweetstock_app`

- **sweetstock_desktop** — App de escritorio Python/Windows
  Repositorio: https://github.com/yhobany/sweetstock_desktop
  Ruta local: `C:\Users\angel\sweetstock_desktop`

## Regla crítica — Cambios en modelos de datos

Cualquier cambio en el esquema de Firebase Firestore (agregar, renombrar, eliminar
o cambiar el tipo de un campo en las colecciones `productos`, `movimientos` o `usuarios`)
**DEBE aplicarse simultáneamente en ambos proyectos**:

- Flutter: `lib/producto_modelo.dart`, `lib/movimiento_modelo.dart`, `lib/usuario_modelo.dart`
- Python: `src/models/producto.py`, `src/models/movimiento.py`, `src/models/usuario.py`

Nunca proponer ni ejecutar un cambio de esquema en un solo proyecto sin advertir
que el otro proyecto también debe actualizarse.
