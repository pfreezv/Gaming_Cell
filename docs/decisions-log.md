# PRIMORDIAL — Registro de Decisiones

Cada decisión de diseño o arquitectura relevante se documenta aquí con fecha y razonamiento.  
Formato: `## [FECHA] Título de la decisión`

---

## [2026-03-28] El jugador actúa sobre el entorno, no sobre organismos

**Decisión:**
El núcleo jugable será de estrategia indirecta: manipular condiciones del entorno para sesgar resultados químicos.

**Motivo:**
Esto diferencia el proyecto de city-builders, RTS clásicos o juegos de supervivencia celular. Además encaja mejor con el tema de abiogénesis.

**Consecuencias:**
- La UI debe priorizar causalidad y lectura sistémica.
- Las acciones del jugador serán “palancas” ambientales, no órdenes unitarias.
- La progresión dependerá de umbrales emergentes.

---

## [2026-03-28] Base técnica en Godot 4 + GDScript

**Decisión:**
El motor principal será Godot 4 y la lógica inicial estará en GDScript.

**Motivo:**
Permite iterar rápido, prototipar sistemas emergentes con agilidad y mantener una base razonable para herramientas visuales y UI.

**Consecuencias:**
- El código debe modularizarse pronto para evitar “spaghetti systems”.
- Los cálculos pesados podrán migrar más adelante a módulos optimizados si fuera necesario.

---

## [2026-03-28] Parámetros científicos externalizados a JSON

**Decisión:**
Los parámetros numéricos del modelo irán en `src/data/science-params.json`.

**Motivo:**
Separar reglas del modelo y código facilita balanceo, trazabilidad y experimentación.

**Consecuencias:**
- Menos números mágicos en GDScript.
- Más facilidad para testear variantes.
- Posibilidad futura de presets por bioma/escenario.

---

## [2026-03-28] GameState como contenedor global explícito

**Decisión:**
Usar un `GameState` centralizado como autoload para el estado global.

**Motivo:**
Evita dispersión temprana del estado y facilita inspección y depuración durante prototipado.

**Consecuencias:**
- Debe usarse con disciplina.
- La lógica pesada no debe vivir ahí.
- Habrá que vigilar que no se convierta en “objeto Dios”.

---

## [2026-03-28] Primer hito técnico: bucle molecular legible antes que fidelidad total

**Decisión:**
Antes de expandir catálogo molecular o detalle científico, se prioriza un bucle estable y entendible.

**Motivo:**
Un sistema científicamente rico pero opaco no será jugable ni depurable.

**Consecuencias:**
- Primero claridad, luego complejidad.
- Telemetría y visualización tempranas son obligatorias.
- Las simplificaciones iniciales son aceptables si conservan el espíritu del modelo.

---

## [2026-03-28] Git LFS preparado desde el inicio para assets pesados

**Decisión:**
Declarar desde el inicio los formatos binarios pesados en `.gitattributes` para Git LFS.

**Motivo:**
Evita problemas futuros de peso e historial cuando entren sprites, audio y recursos visuales reales.

**Consecuencias:**
- Los colaboradores deben tener Git LFS instalado.
- Los assets finales deben respetar nomenclaturas y pipelines claros.
