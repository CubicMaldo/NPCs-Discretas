# Guía de Migración: Refactorización del Sistema de Relaciones

## Resumen de Cambios

Se ha refactorizado el sistema de relaciones para eliminar redundancias y mejorar la modularidad. La ejecución de decisiones (behaviour/utility AI) se delega a addons externos y quedó fuera del núcleo del repositorio.

## Cambios Principales

### ✅ 1. Nuevo `SocialComponent` (reemplaza `RelationshipComponent`)

**Antes:**
- `RelationshipComponent` mantenía un caché local de relaciones
- Sincronización manual con `SocialGraphManager` mediante `refresh_from_graph()`
- Riesgo de inconsistencias entre caché local y grafo global

**Ahora:**
- `SocialComponent` es una interfaz limpia sin caché local
- Todas las consultas van directamente al `SocialGraphManager` (fuente única de verdad)
- No hay sincronización manual - siempre datos actualizados
- API más simple y segura

**Archivo:** `scripts/entities/SocialComponent.gd`

### ✅ 2. `Relationship` Resource Extendido

**Antes:**
```gdscript
@export var familiarity: float = 0.0
@export var partner_id: int = -1
```

**Ahora:**
```gdscript
# Dimensiones múltiples
@export var familiarity: float = 0.0
@export var trust: float = 0.5
@export var hostility: float = 0.0

# Historial
@export var interaction_count: int = 0
@export var last_interaction_time: float = 0.0
@export var positive_interactions: int = 0
@export var negative_interactions: int = 0

# Metadata extensible
@export var tags: Array[String] = []
@export var custom_data: Dictionary = {}

# Métodos útiles
func get_relationship_quality() -> float
func is_positive() -> bool
func is_negative() -> bool
func record_positive_interaction(...)
func record_negative_interaction(...)
func apply_decay(...)
```

**Beneficios:**
- Más información para scoring y análisis (utilizable por addons de decisión externos)
- Historial de interacciones para decisiones contextuales
- Decaimiento temporal automático
- Extensible con tags y custom_data

**Archivo:** `scripts/entities/Relationship.gd`

### ✅ 3. `NPC.gd` Simplificado

**Eliminado:**
- `@export var relationship_archetype: Relationship` (ya no se usa como template)
- `relationship_component` → reemplazado por `social_component`
- `update_relationships()` → ya no necesario (sin caché local)
- `set_relationship()` → usar API del social_component directamente
- `_ensure_relationship_component()` → ahora `_ensure_social_component()`

**Nueva API pública simplificada:**
```gdscript
# Consultas de relaciones (delegadas al SocialComponent)
func get_familiarity(partner) -> float
func get_all_relationships() -> Dictionary
func get_strongest_familiarity() -> float
func get_top_relationships(top_n: int = 3) -> Array
func get_friends_above(threshold: float) -> Array

# Deprecated pero mantenidos por compatibilidad
func get_relationship_snapshot() -> Dictionary  # Usar get_all_relationships()
func get_relationship_component() -> SocialComponent  # Acceso directo si necesario
```

**Beneficios:**
- Separación clara de responsabilidades
- Menos código repetido
- API más intuitiva
- Preparado para Utility AI

**Archivo:** `scripts/entities/NPC.gd`

### ✅ 4. Decision execution moved to addons

Behavior/decision execution was intentionally moved out of the core repository. Use a third-party addon (behavior trees or utility AI) and implement a small adapter node that calls into the `SocialComponent` / `SocialGraphManager` API to fetch relationship data. We'll provide integration examples once you add the chosen addons to the project.

## Guía de Migración para Código Existente

### Si usabas `RelationshipComponent` directamente:

**Antes:**
```gdscript
var rel_comp = npc.get_relationship_component()
rel_comp.add_relationship(other_npc, 0.5)
rel_comp.update_familiarity(other_npc, 0.1)
var relationships = rel_comp.get_relationships()
```

**Ahora:**
```gdscript
var social_comp = npc.social_component
social_comp.set_relationship(other_npc, 0.5)
social_comp.update_familiarity(other_npc, 0.1)
var relationships = social_comp.get_all_relationships()

# O usa la API simplificada del NPC:
var familiarity = npc.get_familiarity(other_npc)
var all_rels = npc.get_all_relationships()
```

### Si consultabas relaciones desde otros sistemas:

**Antes:**
```gdscript
var snapshot = npc.get_relationship_snapshot()
for rel in snapshot.values():
    if rel.familiarity > threshold:
        # ...
```

**Ahora:**
```gdscript
# Opción 1: Usar helpers del NPC
var friends = npc.get_friends_above(threshold)

# Opción 2: Consultar directamente
var all_rels = npc.get_all_relationships()
for familiarity in all_rels.values():
    if familiarity > threshold:
        # ...
```

### Si necesitas Relationship Resources con metadata:

El `SocialGraphManager` ahora devuelve floats (familiaridad) en lugar de Resources.
Si necesitas metadata extendida (trust, hostility, historial):

**Opción 1:** Usa `SocialEdgeMeta` en el grafo social
**Opción 2:** Mantén Relationship Resources como configuración/templates
**Opción 3:** Extiende SocialComponent para cachear Resources localmente si realmente lo necesitas

## Impacto en Escenas y Archivos .tscn

Si tienes escenas con NPCs que tienen `RelationshipComponent` como child:

1. Abre la escena en el editor de Godot
2. Selecciona el nodo `RelationshipComponent`
3. Elimínalo (el NPC creará automáticamente `SocialComponent` en runtime)
4. Guarda la escena

O manualmente en el .tscn:
- Busca `[node name="RelationshipComponent" type="Node" parent="."]`
- Reemplaza por `[node name="SocialComponent" type="Node" parent="."]`

## Ventajas de la Nueva Arquitectura

### Para integrar un sistema de decisión (addons):
- Scoring basado en múltiples dimensiones (trust, hostility, familiarity)
- Historial de interacciones para decisiones contextuales
- Acceso directo sin overhead de sincronización

### Para Behavior Trees (beehave):
- Interfaz limpia para consultas en nodos de decisión
- Sin estado local que mantener sincronizado
- Queries rápidas desde el grafo social

### Para Performance:
- Eliminada duplicación de datos (caché local)
- Menos memoria usada por NPC
- Consultas directas al grafo optimizado

### Para Mantenibilidad:
- Única fuente de verdad (SocialGraphManager)
- Menos bugs por desincronización
- API más clara y documentada
- Separación de responsabilidades

## Verificación Post-Migración

1. **Verifica que no haya errores de compilación:**
   - Abre el proyecto en Godot
   - Revisa la consola de salida
   - Si hay errores de "SocialComponent not found", recarga el proyecto (Project → Reload Current Project)

2. **Ejecuta tests existentes:**
   - `scenes/tests/test_resource_metadata.tscn`
   - `scenes/tests/test_social_graph.tscn`

3. **Verifica interacciones NPC:**
   - Los NPCs deben poder interactuar sin errores
   - Las relaciones deben actualizarse en el grafo social
   - `npc.get_familiarity(other)` debe devolver valores correctos

## Próximos Pasos Recomendados

1. Añade el addon de decisión que prefieras (beehave, utility-ai, etc.) dentro de `addons/`.
2. Implementa un pequeño adapter node que mapee las APIs del addon a `SocialComponent`/`SocialGraphManager` (consulta de familiaridad, top friends, etc.).
3. Documentaré ejemplos de integración y nodes adaptadores una vez hayas añadido el addon al repositorio.

3. **Extender metadata:**
   - Agregar más campos a `Relationship` según necesidades
   - Usar `custom_data` para información específica del juego

4. **Optimizar queries:**
   - Implementar caché de queries frecuentes en `SocialComponent` si es necesario
   - Usar LOD para NPCs lejanos (queries menos frecuentes)

## Soporte y Preguntas

Si encuentras problemas después de la migración:

1. Verifica que `social_graph_manager` esté inyectado en el NPC
2. Asegúrate de que `npc_id` esté configurado correctamente
3. Revisa que los NPCs estén registrados en el grafo social (`ensure_npc`)
4. Comprueba los logs de Godot para errores específicos

## Archivos Modificados

- ✅ `scripts/entities/SocialComponent.gd` (NUEVO)
- ✅ `scripts/entities/Relationship.gd` (EXTENDIDO)
- ✅ `scripts/entities/NPC.gd` (REFACTORIZADO)
- ✅ `scripts/systems/BehaviorSystem.gd` (placeholder / removed from core — use addon adapters)
- ⚠️ `scripts/entities/RelationshipComponent.gd` (DEPRECATED - mantener por compatibilidad temporal)

## Archivo a Deprecar (No Eliminar Aún)

`RelationshipComponent.gd` se mantiene en el proyecto para compatibilidad con código legacy, pero ya no debe usarse en código nuevo. Será eliminado en una futura versión cuando todo el código haya migrado.
