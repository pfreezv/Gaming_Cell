# Contribuir a PRIMORDIAL

## Antes de empezar

1. Lee el GDD completo en `docs/GDD-v03.html`
2. Juega el prototipo: `prototype/simulador-prebiotico-v4-2.html`
3. Lee las convenciones de código en `docs/conventions.md`
4. Revisa `docs/decisions-log.md` antes de proponer cambios estructurales

---

## Flujo de trabajo

### Ramas

- `main` → rama estable
- `dev` → integración general
- `feature/*` → nuevas características
- `fix/*` → correcciones puntuales

Ejemplos:
- `feature/molecule-system`
- `feature/ui-cell-panel`
- `fix/resource-leak-pools`

---

## Estándares de código

### GDScript

- Indentación con tabs o 4 espacios, pero consistente dentro del archivo
- Nombres de variables descriptivos, en inglés técnico
- Métodos privados con prefijo `_`
- Nada de números mágicos si puede ir a `science-params.json`
- Cada sistema debe hacer una sola cosa clara

### Principios

- `GameState` contiene estado global, no lógica pesada
- Los sistemas (`MoleculeSystem`, `ReactionSystem`, etc.) deben ser modulares
- Evitar dependencias circulares
- Las constantes científicas van en JSON o en módulo dedicado
- La UI nunca debe contener la lógica central del modelo

---

## Commit messages

Formato recomendado:

- `feat: add molecule diffusion step`
- `fix: prevent duplicated reaction triggers`
- `docs: update decisions log`
- `refactor: split environment tick from molecule update`

---

## Pull requests

Todo PR debe incluir:

1. Objetivo del cambio
2. Archivos principales modificados
3. Riesgos potenciales
4. Cómo probarlo
5. Captura o gif si afecta a UI

---

## Qué NO hacer

- No mezclar cambios de UI con cambios de motor en el mismo PR sin justificarlo
- No hardcodear parámetros científicos dentro de sistemas
- No modificar `GameState` sin revisar impacto global
- No introducir assets finales sin confirmar naming y formato

---

## Registro de decisiones

Si cambias arquitectura, mecánicas base o parámetros científicos importantes:

- añade una entrada en `docs/decisions-log.md`
- explica motivo, tradeoffs y consecuencias

---

## Filosofía del proyecto

PRIMORDIAL no es un arcade químico: es una simulación estratégica con legibilidad, tensión emergente y base científicamente inspirada.

Cada contribución debe mejorar al menos una de estas tres cosas:

- claridad sistémica
- profundidad jugable
- coherencia científica
