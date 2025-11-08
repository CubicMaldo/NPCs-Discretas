# Arquitectura Refactorizada del Sistema Social

## Visión General

El sistema social ha sido rediseñado para eliminar redundancias y mejorar la modularidad. La ejecución de decisiones (behavior/utility AI) se manejará mediante addons externos y no forma parte del core del repositorio.

## Principios de Diseño

### 1. Single Source of Truth (SSOT)
- **`SocialGraphManager`** es la única fuente autoritativa de relaciones
- No hay cachés locales que requieran sincronización manual
- Todas las consultas van directamente al grafo social

### 2. Separación de Responsabilidades
- **`NPC`**: Datos de entidad (posición, estado, emoción, personalidad)
- **`SocialComponent`**: Interfaz entre NPC y grafo social
- **`SocialGraphManager`**: Almacenamiento y algoritmos de grafos
-- **Decision system (addon)**: Lógica de decisión provista por un addon externo (beehave u otro). No forma parte del core.

### 3. Desacoplamiento por Interfaces
- Los sistemas consumen APIs públicas, no acceden a estructuras internas
- Fácil mockear y testear componentes aisladamente
- Cambios internos no rompen dependientes

### 4. Composición sobre Herencia
- Componentes se añaden como nodos child (composición)
- NPCs pueden tener features opcionales sin herencia compleja

## Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                    SocialGraphManager                        │
│  (Autoload - Única fuente de verdad para relaciones)        │
│                                                              │
│  • add_connection(a, b, familiarity)                        │
│  • get_relationships_for(npc) -> Dictionary                 │
│  • get_familiarity(a, b) -> float                           │
│  • get_top_relations(npc, n) -> Array                       │
│  • get_friends_above(npc, threshold) -> Array               │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │ consultas directas
                              │
┌─────────────────────────────┴───────────────────────────────┐
│                     SocialComponent                          │
│   (Node child del NPC - Interfaz limpia)                    │
│                                                              │
│  • get_relationship(partner) -> float                       │
│  • get_all_relationships() -> Dictionary                    │
│  • set_relationship(partner, familiarity)                   │
│  • update_familiarity(partner, delta)                       │
│  • get_top_relationships(n) -> Array                        │
│  • get_strongest_relationship() -> float                    │
└──────────────────────────────────────────────────────────────┘
                              ▲
                              │ usa
                              │
┌──────────────────────────────────────────────────────────────┐
│                           NPC                                │
│   (CharacterBody2D - Entidad principal)                     │
│                                                              │
│  Datos:                                                      │
│  • npc_id, npc_name                                          │
│  • personality: Personality                                  │
│  • current_emotion: Emotion                                  │
│  • current_state: String                                     │
│                                                              │
│  API Pública (delegada a SocialComponent):                  │
│  • get_familiarity(partner) -> float                        │
│  • get_all_relationships() -> Dictionary                    │
│  • get_strongest_familiarity() -> float                     │
│  • get_top_relationships(n) -> Array                        │
│  • get_friends_above(threshold) -> Array                    │
│                                                              │
│  Comportamiento:                                             │
│  • interact_with(other_npc)                                 │
│  • choose_action() -> String                                │
└──────────────────────────────────────────────────────────────┘
                              ▲
                              │ consulta
                              │
┌──────────────────────────────────────────────────────────────┐
│                 DecisionSystem (addon)                        │
│   (Node - Sistema de decisión)                              │
│                                                              │
│  • choose_action_for(npc) -> String                         │
│    - Lee npc.get_strongest_familiarity()                    │
│    - Lee npc.current_emotion.intensity                      │
│    - Calcula weights para acciones                          │
│    - Devuelve "interact" | "walk" | "ignore" | "idle"      │
│                                                              │
│  Preparado para reemplazo por Utility AI                    │
└──────────────────────────────────────────────────────────────┘
```

## Flujo de Datos: Interacción entre NPCs

```
1. NPC_A.interact_with(NPC_B)
   │
   ├─→ SocialGraphManager.register_interaction(A, B)
   │   └─→ Actualiza grafo interno
   │
    ├─→ DecisionSystem.notify_interaction(A, B)  # Optional adapter hook from addons
   │
   └─→ social_component.update_familiarity(B, delta)
       └─→ SocialGraphManager.set_familiarity(A, B, new_value)
           └─→ Actualiza arista A→B en grafo

2. DecisionSystem.choose_action_for(NPC_A)
   │
   └─→ npc.get_strongest_familiarity()
       └─→ social_component.get_strongest_relationship()
           └─→ SocialGraphManager.get_relationships_for(A)
               └─→ Devuelve Dictionary de relaciones desde grafo
```

## Modelo de Datos

### Relationship Resource (Extendido)
```gdscript
class_name Relationship extends Resource

# Dimensiones de relación
@export var familiarity: float    # Qué tan conocido (0-1)
@export var trust: float          # Confianza (0-1)
@export var hostility: float      # Hostilidad (0-1)

# Historial
@export var interaction_count: int
@export var positive_interactions: int
@export var negative_interactions: int
@export var last_interaction_time: float

# Extensible
@export var tags: Array[String]
@export var custom_data: Dictionary

# Métodos de utilidad
func get_relationship_quality() -> float
func is_positive() -> bool
func is_negative() -> bool
func record_positive_interaction(...)
func record_negative_interaction(...)
func apply_decay(delta_time, decay_rate)
```

**Uso:**
- Como template/archetype para configuración inicial
- Para metadata local si el grafo social solo almacena floats
- En sistemas que necesiten más información que solo familiaridad

### SocialGraphManager Storage
- Almacena **floats** (familiaridad) en aristas dirigidas
- Opcionalmente puede almacenar `SocialEdgeMeta` (Resource) con más info
- Optimizado para queries rápidas de vecindad y pathfinding

## Integración con Sistemas Futuros

### Decision systems and addons

This repository does not implement an in-core decision system. Instead, decision execution (behavior trees, utility scoring, FSM, etc.) should be provided by a third-party addon. The recommended approach is:

- Add the decision addon you prefer into the `addons/` folder (for example, a behavior-tree addon or a utility-scoring addon).
- Implement a small adapter node or glue layer that maps the addon API to the project's public social API (`SocialComponent` / `SocialGraphManager`).
- Keep scoring/condition code in the addon or adapter; use the NPC / SocialComponent APIs for relationship queries (e.g. `npc.get_familiarity()`, `npc.get_top_relationships()`).

When you add a specific addon to the project I can generate concrete adapter examples (scoring hooks, Condition nodes, or FSM evaluators) that call into the social graph.

## Ventajas de la Nueva Arquitectura

### ✅ Eliminación de Redundancias
- **Antes:** Datos en `SocialGraphManager` + caché en `RelationshipComponent`
- **Ahora:** Solo en `SocialGraphManager`
- **Ahorro:** ~50-100 bytes por NPC (dependiendo de número de relaciones)

### ✅ Consistencia Garantizada
- **Antes:** Posibles desincronizaciones entre caché y grafo
- **Ahora:** Siempre datos actualizados desde fuente única

### ✅ API más Clara
- **Antes:** `npc.relationship_component.get_relationships()` devolvía `Dictionary<int, Relationship>`
- **Ahora:** `npc.get_all_relationships()` devuelve `Dictionary<Variant, float>`
- Más directo, menos conversiones

### ✅ Mejor Performance
- Consultas directas al grafo optimizado (cachés internos, estructuras eficientes)
- Sin overhead de mantener múltiples cachés sincronizados
- Menos allocations (no crear Relationship Resources por query)

### ✅ Extensibilidad
- Fácil agregar nuevos componentes (InventoryComponent, QuestComponent, etc.)
- Patrón claro para delegar a managers centralizados
- Preparado para networking (SSOT facilita sincronización)

## Testing y Validación

### Tests Unitarios Recomendados
```gdscript
# test_social_component.gd

func test_get_relationship_returns_correct_value():
    var npc_a = NPC.new()
    var npc_b = NPC.new()
    npc_a.npc_id = 1
    npc_b.npc_id = 2
    
    var graph_mgr = SocialGraphManager.new()
    npc_a.set_systems(graph_mgr, null)
    
    graph_mgr.set_familiarity(npc_a, npc_b, 0.7)
    
    assert_eq(npc_a.get_familiarity(npc_b), 0.7)

func test_update_familiarity_modifies_graph():
    # ...
```

### Tests de Integración
- Verificar interacciones NPC→NPC actualizan grafo
- Confirmar que el adapter/DecisionSystem (addon) obtiene datos correctos
- Validar que múltiples NPCs no interfieren entre sí

### Tests de Regresión
- Ejecutar escenas de prueba existentes
- Verificar que gameplay no ha cambiado
- Confirmar que serializacion/deserializacion funciona

## Patrones de Uso Comunes

### Obtener el mejor amigo de un NPC
```gdscript
var top_friends = npc.get_top_relationships(1)
if top_friends.size() > 0:
    var best_friend_id = top_friends[0]
    print("Best friend: ", best_friend_id)
```

### Contar enemigos (hostilidad > 0.5)
```gdscript
# Opción 1: Extender SocialComponent con get_enemies_above()
var enemies = npc.social_component.get_enemies_above(0.5)

# Opción 2: Iterar (menos eficiente)
var enemy_count = 0
var all_rels = npc.get_all_relationships()
for partner_key in all_rels.keys():
    var familiarity = all_rels[partner_key]
    # Necesitarías consultar hostility del grafo o Relationship Resource
```

### Aplicar decaimiento temporal a todas las relaciones
```gdscript
# En GameManager o TimeManager

func _on_day_passed():
    var decay_result = social_graph_manager.apply_decay(86400.0) # 1 día
    print("Decayed ", decay_result.edges_decayed, " relationships")
```

## Próximos Pasos Sugeridos

1. **Implementar Utility AI completo:**
   - `UtilityAI.gd` autoload
   - `UtilityAction.gd` base class
   - Actions concretas (GreetAction, IgnoreAction, HelpAction, InsultAction)

2. **Crear UtilitySelector para beehave:**
   - Nodo composite personalizado
   - Integración con sistema de scoring
   - Hysteresis y throttling

3. **Extender Relationship metadata:**
   - Agregar campos específicos del juego (loyalty, romance, rivalry)
   - Implementar decaimiento automático por tiempo
   - Tags para categorizar relaciones (family, guild, rival_faction)

4. **Optimizar queries frecuentes:**
   - Caché de `get_strongest_familiarity` con TTL
   - LOD para NPCs lejanos (evaluar menos frecuentemente)
   - Batch queries para múltiples NPCs

5. **Networking:**
   - Decidir si SocialGraphManager vive en servidor o cliente
   - Sincronizar solo cambios (deltas) en lugar de estado completo
   - Usar npc_id en lugar de referencias para serialización

## Referencias

- `scripts/entities/SocialComponent.gd` - Implementación del componente
- `scripts/entities/Relationship.gd` - Resource extendido con metadata
- `scripts/entities/NPC.gd` - API pública simplificada
- `scripts/systems/BehaviorSystem.gd` - (placeholder) Decision logic should be provided by an addon and adapters
- `MIGRATION_GUIDE.md` - Guía paso a paso para migrar código existente
