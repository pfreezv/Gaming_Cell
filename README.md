# PRIMORDIAL — La Célula que Ganará

> El primer juego de estrategia ambientado en el origen molecular de la vida.

[![Estado](https://img.shields.io/badge/estado-prototipo_v4.2-orange)]()
[![Motor](https://img.shields.io/badge/motor-Godot_4-blue)]()
[![Género](https://img.shields.io/badge/género-estrategia_+_simulación-green)]()
[![Fase](https://img.shields.io/badge/fase-preproducción-yellow)]()

---

## Visión

**PRIMORDIAL** es un juego de estrategia / simulación donde el jugador no controla un héroe ni una civilización, sino un entorno prebiótico en el borde del caos.  
Su objetivo es conducir, favorecer o forzar las condiciones que permitan el surgimiento de una **protocélula estable**, antes de que el sistema colapse o quede estancado.

El juego combina:

- simulación química emergente
- estrategia indirecta
- gestión de recursos moleculares
- eventos geológicos y ambientales
- progresión hacia complejidad funcional

---

## Fantasía jugable

No juegas a *ser una célula*.
Juegas a **crear las condiciones para que aparezca una**.

Eso implica:

- modular temperatura, energía, ciclos húmedo-seco y gradientes
- favorecer la concentración de compuestos útiles
- gestionar entornos como charcas, arcillas, fumarolas y microcompartimentos
- impulsar rutas químicas que compitan entre sí
- sobrevivir a la entropía, la degradación y la escasez

---

## Objetivo principal

Guiar el sistema desde un “caldo químico caótico” hasta la aparición de una **protocélula viable**, definida por la convergencia de:

1. compartimentalización
2. metabolismo rudimentario
3. almacenamiento / transmisión de información
4. estabilidad suficiente para persistir

---

## Pilares de diseño

### 1. Estrategia indirecta
El jugador no da órdenes unitarias a entidades vivas.  
Manipula variables del entorno y sesga probabilidades.

### 2. Complejidad emergente
Las moléculas interactúan con reglas locales simples, produciendo comportamientos globales no triviales.

### 3. Legibilidad sistémica
Aunque haya profundidad científica, el jugador debe entender por qué gana o pierde.

### 4. Ciencia inspirada, no dogmática
El juego se inspira en hipótesis reales sobre abiogénesis, pero prioriza diseño, claridad y tensión jugable.

### 5. Progresión hacia umbrales
El progreso no va de “niveles”, sino de **transiciones críticas** del sistema.

---

## Loop jugable resumido

1. El jugador observa el estado químico y ambiental.
2. Introduce o modula condiciones del entorno.
3. El sistema molecular evoluciona en ticks.
4. Surgen concentraciones, rutas o estructuras útiles.
5. El jugador estabiliza lo prometedor y amortigua el colapso.
6. Si se alcanza un conjunto de umbrales, emerge una protocélula.

---

## Entornos previstos

- charcas someras
- fuentes hidrotermales
- superficies minerales / arcillas
- interfaces agua-roca
- microcavidades
- ciclos evaporación-rehidratación

Cada entorno altera probabilidades de:

- concentración
- degradación
- difusión
- polimerización
- encapsulación
- persistencia

---

## Sistemas nucleares previstos

- **MoleculeSystem** → moléculas, pools, estados y movimiento
- **ReactionSystem** → reglas de interacción y reacciones
- **EnvironmentSystem** → temperatura, pH, energía, humedad, gradientes
- **CompartmentSystem** → vesículas, poros, membranas primitivas
- **ProgressSystem** → hitos, umbrales y evaluación de complejidad
- **EventSystem** → perturbaciones y eventos del entorno
- **UI/Telemetry** → visualización, paneles y causalidad legible

---

## Estado actual

El repositorio arranca con la base de preproducción técnica:

- estructura inicial del proyecto
- sistema de estado global
- primer sistema molecular
- parámetros científicos externalizados a JSON
- documentación viva de decisiones

Esto **no es aún un juego completo**, sino el esqueleto del motor y la dirección de diseño.

---

## Estructura del repositorio

```text
.
├── assets/
│   └── sprites/
├── docs/
├── src/
│   ├── core/
│   └── data/
├── CONTRIBUTING.md
└── README.md
```

---

## Stack técnico

- **Engine**: Godot 4
- **Lenguaje principal**: GDScript
- **Datos de simulación**: JSON
- **Assets pesados**: previstos con Git LFS

---

## Próximos hitos sugeridos

### S1 — Base de simulación
- tick estable
- pools moleculares
- difusión / degradación
- panel mínimo de telemetría

### S2 — Reacciones químicas
- motor de reacciones parametrizable
- probabilidades dependientes del entorno
- eventos energéticos

### S3 — Compartimentalización
- vesículas rudimentarias
- ventajas / costes de encapsulación
- persistencia diferencial

### S4 — Condición de protocélula
- criterios compuestos de emergencia
- evaluación de estabilidad
- pantalla de transición / victoria inicial

---

## Filosofía de desarrollo

El proyecto debe crecer con una lógica muy clara:

- primero sistemas pequeños pero robustos
- después interacción entre sistemas
- luego visualización legible
- por último expansión de contenido

No conviene empezar por “más moléculas” si aún no hay un bucle sólido y comprensible.

---

## Documentación relacionada

- `docs/decisions-log.md` → decisiones de arquitectura y diseño
- `src/core/GameState.gd` → estado global del juego
- `src/core/MoleculeSystem.gd` → núcleo del sistema molecular
- `src/data/science-params.json` → parámetros científicos del modelo
- `src/data/schema/sim-v1.json` → contrato mínimo de telemetría (`state_snapshot` y `event`)
- `tools/telemetry-viewer.html` → visualizador web MVP para snapshots/eventos

---

## Contribución

Lee `CONTRIBUTING.md` antes de proponer cambios estructurales.

---

## Nota

PRIMORDIAL busca una mezcla rara:  
**rigor suficiente para sentirse plausible** y **claridad suficiente para ser jugable**.

Ese equilibrio es el corazón del proyecto.
