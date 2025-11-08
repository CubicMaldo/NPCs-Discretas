# Próximos Pasos: Implementación de Utility AI

## Estado Actual ✅

Después de la refactorización, el sistema está preparado para integrar Utility AI de manera modular:

- ✅ `SocialComponent` proporciona interfaz limpia para consultas de relaciones
- ✅ `Relationship` tiene múltiples dimensiones (familiarity, trust, hostility)
- ✅ `NPC.gd` expone API pública simple
- ✅ `BehaviorSystem.gd` desacoplado y listo para reemplazo
- ✅ Arquitectura modular que permite FSM o BT como executors

## Plan de Implementación de Utility AI

### Fase 1: Core del Sistema (2-4 horas)

#### 1.1 Crear `UtilityAI.gd` (Autoload)
```gdscript
# res://scripts/core/UtilityAI.gd
extends Node
class_name UtilityAI

var registered_actions: Array[UtilityAction] = []
@export var evaluation_interval: float = 0.3
@export var tie_breaker_noise: float = 0.0001
@export var threshold: float = 0.05

func register_action(action: UtilityAction) -> void
func unregister_action(action: UtilityAction) -> void
func evaluate(npc: NPC, context: Dictionary) -> Array[ActionScore]
func get_best_action(npc: NPC, context: Dictionary) -> ActionScore
```

**Archivo:** `scripts/core/UtilityAI.gd`

#### 1.2 Crear `UtilityAction.gd` (Base Class)
```gdscript
# res://scripts/entities/UtilityAction.gd
extends Resource
class_name UtilityAction

@export var action_name: String = ""
@export var cooldown: float = 0.0
@export var interruptible: bool = true
@export var min_score_threshold: float = 0.0

var _last_executed_time: float = -9999.0

# Override en subclases
func score(npc: NPC, context: Dictionary) -> float
func can_start(npc: NPC, context: Dictionary) -> bool
func start(npc: NPC, context: Dictionary) -> void
func update(npc: NPC, dt: float, context: Dictionary) -> int # RUNNING=0, SUCCESS=1, FAIL=2
func stop(npc: NPC, context: Dictionary) -> void
```

**Archivo:** `scripts/entities/UtilityAction.gd`

#### 1.3 Crear `ActionScore.gd` (Data Container)
```gdscript
# res://scripts/core/ActionScore.gd
class_name ActionScore

var action: UtilityAction
var score: float
var context: Dictionary = {}
var timestamp: float = 0.0

func _init(p_action: UtilityAction, p_score: float, p_context: Dictionary = {}):
    action = p_action
    score = p_score
    context = p_context
    timestamp = Time.get_ticks_msec() / 1000.0
```

**Archivo:** `scripts/core/ActionScore.gd`

#### 1.4 Configurar Autoload
En Godot Editor:
1. Project → Project Settings → Autoload
2. Add: Path = `res://scripts/core/UtilityAI.gd`, Name = `UtilityAI`
3. Enable

### Fase 2: Acciones Concretas (3-5 horas)

Crear acciones sociales básicas usando la nueva API de `SocialComponent`:

#### 2.1 GreetAction
```gdscript
# res://scripts/entities/actions/GreetAction.gd
extends UtilityAction
class_name GreetAction

@export var familiarity_bonus: float = 0.6
@export var friend_threshold: float = 0.5
@export var stranger_penalty: float = 0.2

func score(npc: NPC, context: Dictionary) -> float:
    # Utility AI next-steps removed

    This document previously contained an in-repo plan and scaffolding for a built-in Utility AI implementation. Per repository scope, decision-making systems have been removed from the core. Please add your preferred decision addon (e.g., beehave or another Utility AI addon) under `addons/` and I will generate adapter examples and documentation for that addon on request.
    # Pedir scores a UtilityAI
    var context = _build_context(actor, blackboard)
    var candidates = UtilityAI.evaluate(actor, context)
    
    if candidates.size() == 0:
        return FAILURE
    
    var best = candidates[0]
    
    # Cambiar solo si supera hysteresis
    if current_child_index == -1 or best.score >= current_score + hysteresis:
        var new_child_index = _map_action_to_child(best.action)
        if new_child_index != -1:
            current_child_index = new_child_index
            current_score = best.score
    
    return RUNNING

func _build_context(actor, blackboard) -> Dictionary:
    return {
        "actor": actor,
        "blackboard": blackboard,
        "nearby_npcs": blackboard.get("nearby_npcs", [])
    }

func _map_action_to_child(action: UtilityAction) -> int:
    # Mapear action_name a child index
    for i in children.size():
        var child = children[i]
        if child.has_meta("action_name") and child.get_meta("action_name") == action.action_name:
            return i
    return -1
```

**Archivo:** `addons/beehave/custom_nodes/UtilitySelector.gd`

### Fase 4: Testing y Calibración (2-3 horas)

#### 4.1 Crear Escena de Prueba
```
res://scenes/tests/test_utility_ai.tscn
├─ Node2D (root)
│  ├─ NPC (id=1, name="Alice")
│  ├─ NPC (id=2, name="Bob")
│  └─ DebugOverlay (Label mostrando scores)
```

#### 4.2 Script de Test
```gdscript
# res://scripts/tests/TestUtilityAI.gd
extends Node2D

@onready var alice = $Alice
@onready var bob = $Bob
@onready var debug_label = $DebugOverlay

func _ready():
    # Registrar acciones
    var greet = GreetAction.new()
    greet.action_name = "greet"
    var ignore = IgnoreAction.new()
    ignore.action_name = "ignore"
    var help = HelpAction.new()
    help.action_name = "help"
    
    UtilityAI.register_action(greet)
    UtilityAI.register_action(ignore)
    UtilityAI.register_action(help)
    
    # Setup relaciones
    alice.social_component.set_relationship(bob, 0.7) # Amigos
    bob.social_component.set_relationship(alice, 0.6)

func _process(_delta):
    # Mostrar scores en tiempo real
    var context = {"target_npc": bob}
    var scores = UtilityAI.evaluate(alice, context)
    
    var text = "Alice → Bob:\n"
    for score in scores:
        text += "  %s: %.2f\n" % [score.action.action_name, score.score]
    debug_label.text = text
```

#### 4.3 Calibración de Pesos
Ajustar exports en cada acción:
- `GreetAction.familiarity_bonus` (0.4 - 0.8)
- `IgnoreAction.baseline_score` (0.1 - 0.3)
- `HelpAction.friend_bonus` (0.3 - 0.7)

Observar en tiempo real con el debug overlay y ajustar hasta que el comportamiento sea natural.

### Fase 5: Documentación y Limpieza (1 hora)

#### 5.1 Crear README de Utility AI
```markdown
# Utility AI System

## Cómo Crear una Nueva Acción

1. Crear script que extienda `UtilityAction`
2. Override `score()`, `can_start()`, `start()`, `update()`, `stop()`
3. Exportar parámetros ajustables
4. Registrar en `UtilityAI` autoload

## Cómo Ajustar Comportamiento

- Aumentar `evaluation_interval` → decisiones menos frecuentes (mejor perf)
- Aumentar `threshold` → solo acciones con score alto
- Aumentar hysteresis → menos flip-flopping entre acciones

## Debugging

- Activar `DebugOverlay` en escenas de prueba
- Logs en `start()` de cada acción
- Usar `UtilityAI.get_best_action()` en inspector
```

**Archivo:** `docs/UTILITY_AI_GUIDE.md`

## Estimación de Tiempo Total

| Fase | Tiempo Estimado | Complejidad |
|------|----------------|-------------|
| Fase 1: Core | 2-4 horas | Media |
| Fase 2: Acciones | 3-5 horas | Baja-Media |
| Fase 3: Integración | 2-3 horas | Media-Alta |
| Fase 4: Testing | 2-3 horas | Baja |
| Fase 5: Docs | 1 hora | Baja |
| **TOTAL** | **10-16 horas** | - |

## Checklist de Implementación

- [ ] Crear `UtilityAI.gd` autoload
- [ ] Crear `UtilityAction.gd` base class
- [ ] Crear `ActionScore.gd` data container
- [ ] Implementar `GreetAction`
- [ ] Implementar `IgnoreAction`
- [ ] Implementar `HelpAction`
- [ ] Crear `FSMExecutor` O `UtilitySelector` (beehave)
- [ ] Integrar executor en `NPC.gd`
- [ ] Crear escena de prueba `test_utility_ai.tscn`
- [ ] Calibrar pesos de acciones
- [ ] Documentar sistema en `docs/UTILITY_AI_GUIDE.md`
- [ ] Reemplazar `BehaviorSystem` legacy (opcional)

## Siguientes Mejoras (Post-Implementación)

1. **Consideraciones por Role/Personality:**
   - Acciones específicas por tipo de NPC
   - Pesos ajustados por traits de personalidad

2. **Context Provider avanzado:**
   - Detección de eventos del mundo
   - Memoria de interacciones pasadas
   - Goals y necesidades del NPC

3. **Optimizaciones:**
   - LOD para NPCs lejanos
   - Batch evaluation para múltiples NPCs
   - Cache de queries costosas

4. **Integración completa con beehave:**
   - Múltiples `UtilitySelector` en diferentes niveles del árbol
   - Leaves que usan actions de Utility AI
   - Hybrid: Utility para strategy, BT para tactics

5. **Telemetría:**
   - Logging de decisiones para análisis
   - Heatmaps de acciones más ejecutadas
   - Balance automático de pesos via ML (avanzado)

## Recursos Adicionales

- [GDC Talk: Utility AI for Games](https://www.gdcvault.com/play/1021848/)
- [Building Utility AI in Godot](https://kidscancode.org/godot_recipes/4.x/ai/utility_ai/)
- [beehave Documentation](https://github.com/bitbrain/beehave)

¡Listo para implementar! 🚀
