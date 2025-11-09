# Integración de Behaviour Trees con Utility AI

Este documento explica cómo el sistema de NPC ahora combina **Utility AI** (para la selección de acciones) con **Behaviour Trees de Beehave** (para la ejecución de comportamientos).

## Arquitectura Híbrida

### Utility AI - Selección de Acciones
El `UtilityAiAgent` del NPC evalúa periódicamente todas las acciones disponibles:
- Cada acción tiene **Considerations** (consideraciones) que devuelven un score (0..1).
- Las considerations leen el estado del NPC (hunger, energy, stress, is_safe, etc.).
- El agente selecciona la acción con mayor score aplicando hysteresis para evitar cambios rápidos.

### Behaviour Trees - Ejecución de Comportamientos
Cada acción seleccionada ejecuta un **Beehave Tree** (árbol de comportamiento):
- `ActionBT` wrapper instancia y activa el árbol BT correspondiente.
- El árbol BT ejecuta hojas (leaves) que implementan el comportamiento concreto.
- Las hojas ya no toman decisiones globales ni buscan nodos en el SceneTree; en su lugar usan la API pasiva del NPC (por ejemplo `set_target(node)`, `consume_target_if_food()`, `start_eating()`, `finish_eating()`, `start_sleeping()`, `finish_sleeping()`, `arrived()`, `has_target()`) y los helpers `get_closest_food()` / `get_closest_shelter()` para consultar el mundo.
- Cuando el BT termina, escribe `"action_done"` en su blackboard.
- `ActionBT` detecta la finalización y notifica al agente Utility AI.

## Estructura de Archivos

### Hojas de Beehave (Leaves)
Ubicación: `example/ai/bt/leaves/`

- **idle_leaf.gd** - Idle por duración configurable; solicita al NPC reproducir la animación `idle()`.
- **eat_leaf.gd** - Comprueba que el NPC tenga comida, invoca `start_eating()` y usa su propio temporizador / espera hasta `finish_eating()`.
- **sleep_leaf.gd** - Dirige al NPC a una ubicación de descanso y usa `start_sleeping()` / `finish_sleeping()` para gestionar el sueño.
- **find_food_leaf.gd** - Usa `actor.get_closest_food()` (fallback a búsqueda global), llama `actor.set_target(food_node)` y espera `actor.arrived()` antes de `actor.consume_target_if_food()`.
- **find_shelter_leaf.gd** - Usa `actor.get_closest_shelter()` (fallback a búsqueda global), llama `actor.set_target(shelter_node)` y espera `actor.arrived()` antes de marcar `is_safe`.
- **relax_leaf.gd** - Idle por duración mientras se reduce el estrés (usa `idle()` en el NPC).

### Árboles de Beehave (Trees)
Ubicación: `example/ai/bt/trees/`

- **idle_bt.tscn** - Árbol con una sola hoja `IdleLeaf`
- **eat_bt.tscn** - Árbol con `EatLeaf`
- **sleep_bt.tscn** - Árbol con `SleepLeaf`
- **find_food_bt.tscn** - Árbol con `FindFoodLeaf`
- **find_shelter_bt.tscn** - Árbol con `FindShelterLeaf`
- **relax_bt.tscn** - Árbol con `RelaxLeaf`

### Wrappers de Acción BT
Ubicación: `example/ai/actions/`

- **action_bt_idle.tscn** - Acción que ejecuta `idle_bt.tscn`
- **action_bt_eat.tscn** - Acción que ejecuta `eat_bt.tscn`
- **action_bt_sleep.tscn** - Acción que ejecuta `sleep_bt.tscn`
- **action_bt_find_food.tscn** - Acción que ejecuta `find_food_bt.tscn`
- **action_bt_look_for_shelter.tscn** - Acción que ejecuta `find_shelter_bt.tscn`
- **action_bt_relax.tscn** - Acción que ejecuta `relax_bt.tscn`

Cada wrapper:
- Extiende `UtilityAiAction` vía script `action_bt.gd`
- Apunta a su árbol BT correspondiente (export `bt_scene`)
- Mantiene las **Considerations** originales como nodos hijos

## Flujo de Ejecución

1. **Evaluación** (Utility AI):
   - El `UtilityAiAgent` calcula scores para todas las acciones cada `sampling_interval`.
   - Cada acción usa sus Considerations (por ejemplo, "hunger", "energy", "is_safe").

2. **Selección** (Utility AI):
   - El agente selecciona la acción con mayor score.
   - Aplica `hysteresis_margin` para evitar cambios por pequeñas fluctuaciones.
   - Respeta `cooldown` y `post_stop_block_time` para evitar re-selección inmediata.

3. **Inicio** (ActionBT):
   - `ActionBT.start(agent)` instancia el árbol BT desde `bt_scene`.
   - Asigna `bt_tree.actor = agent.get_parent()` (el NPC CharacterBody2D). Esto asegura que las hojas reciban el actor que contiene la lógica, propiedades y posición, no el `UtilityAiAgent` node.
   - Activa el árbol con `bt_tree.enabled = true`.

4. **Ejecución** (Beehave Tree):
   - El árbol BT ejecuta sus hojas secuencialmente.
   - Las hojas usan la API pasiva del NPC para realizar acciones y comprobar estado (por ejemplo `actor.set_target(node)` y `actor.arrived()` en lugar de que la hoja misma busque nodos globalmente).
   - Ejemplo: `FindFoodLeaf` obtiene `actor.get_closest_food()`, llama `actor.set_target(food_node)` y espera hasta que `actor.arrived()`; luego llama `actor.consume_target_if_food()`.

5. **Finalización** (Beehave Leaf → ActionBT):
   - Cuando la hoja termina, escribe en el blackboard del árbol:
     ```gdscript
     blackboard.set_value("action_done", true, str(actor.get_instance_id()))
     ```
   - `ActionBT.tick()` detecta el flag y llama `complete()`.

6. **Limpieza** (ActionBT):
   - `ActionBT.stop()` libera el árbol BT (`queue_free()`).
   - El agente puede ahora seleccionar otra acción.

## Ventajas de esta Arquitectura

### Separación de Responsabilidades
- **Utility AI**: "¿Qué debería hacer?" (decisión estratégica basada en estado).
- **Behaviour Tree**: "¿Cómo lo hago?" (implementación táctica del comportamiento).

### Modularidad
- Las considerations se pueden ajustar en el editor sin tocar código BT.
- Los árboles BT se pueden expandir con secuencias, condicionales, y loops sin modificar el Utility AI.

### Reutilización
- Un mismo árbol BT puede ser usado por múltiples acciones.
- Las hojas son reutilizables en diferentes árboles.

### Depuración
- Los scores del Utility AI son visibles en `utility_debug.tscn`.
- Los árboles BT se pueden inspeccionar en tiempo de ejecución con herramientas de Beehave.

## Cambios en `npc.gd`

El NPC ahora expone una API pasiva que el BT y las Actions deben usar para controlar al actor. En lugar de que el NPC busque y tome decisiones, ofrece helpers y mutadores que el BT invoca.

Ejemplos de helpers expuestos por `npc.gd`:

- `set_target(node)` / `clear_target()` — asignar/limpiar objetivo de movimiento
- `has_target()` / `arrived(threshold)` — consultas sobre el objetivo actual
- `consume_target_if_food()` — consumir el objetivo si es del grupo `food`
- `start_eating()` / `finish_eating()` — entrar/salir del estado de comer
- `start_sleeping()` / `finish_sleeping()` — entrar/salir del estado de dormir
- `get_closest_food()` / `get_closest_shelter()` — helpers que centralizan la búsqueda en el NPC

El método `_on_utility_ai_agent_top_score_action_changed()` ya no ejecuta comportamientos directamente; `ActionBT` instancia el árbol y las hojas controlan la ejecución a través de la API pasiva.

Resumen (ejemplo mínimo de uso desde una hoja BT):

```gdscript
func before_run(actor: Node, blackboard: Node) -> void:
   blackboard.set_value("action_done", false, str(actor.get_instance_id()))
   var food = null
   if "get_closest_food" in actor:
      food = actor.get_closest_food()
   if food and "set_target" in actor:
      actor.set_target(food)

func tick(actor: Node, blackboard: Node) -> int:
   if "has_target" in actor and actor.has_target():
      if actor.arrived():
         if "consume_target_if_food" in actor:
            actor.consume_target_if_food()
         blackboard.set_value("action_done", true, str(actor.get_instance_id()))
         return BeehaveNode.SUCCESS
      return BeehaveNode.RUNNING
   blackboard.set_value("action_done", true, str(actor.get_instance_id()))
   return BeehaveNode.SUCCESS
```

## Configuración en npc.tscn

El `UtilityAiAgent` tiene `auto_execute_actions = true` para que el agente automáticamente llame `start()` en la acción seleccionada.

Cada acción en la escena:
1. Es una instancia de `ActionBT` (ej: `action_bt_eat.tscn`)
2. Tiene sus **Considerations** originales como nodos hijos
3. El wrapper `ActionBT` apunta a su árbol BT correspondiente

Ejemplo de jerarquía en el editor:
```
UtilityAiAgent
├─ Eat (ActionBTEat instance)
│  └─ UtilityAiAggregation
│     ├─ already eating (ConsiderationFromNode)
│     └─ UtilityAiAggregation
│        ├─ hunger (ConsiderationFromNode)
│        └─ food in pocket (ConsiderationFromNode)
├─ Sleep (ActionBTSleep instance)
│  └─ ... (considerations)
└─ ... (más acciones)
```

## Cómo Extender

### Añadir un Nuevo Comportamiento

1. **Crear la hoja BT**:
   ```gdscript
   # example/ai/bt/leaves/nuevo_leaf.gd
   extends BeehaveNode
   
   func before_run(actor: Node, blackboard: Node) -> void:
       blackboard.set_value("action_done", false, str(actor.get_instance_id()))
       # inicialización
   
   func tick(actor: Node, blackboard: Node) -> int:
       # lógica del comportamiento
       if condicion_terminacion:
           blackboard.set_value("action_done", true, str(actor.get_instance_id()))
           return BeehaveNode.SUCCESS
       return BeehaveNode.RUNNING
   ```

2. **Crear el árbol BT** (`nuevo_bt.tscn`):
   - Nodo raíz: `BeehaveTree`
   - Hijo: instancia de `nuevo_leaf.gd`

3. **Crear el wrapper ActionBT** (`action_bt_nuevo.tscn`):
   - Script: `action_bt.gd`
   - Export `_action_id`: "nuevo"
   - Export `bt_scene`: apuntar a `nuevo_bt.tscn`

4. **Añadir Considerations**:
   - En la escena del NPC, instanciar `action_bt_nuevo.tscn` bajo `UtilityAiAgent`
   - Añadir Considerations como hijos para calcular el score

5. **Probar**:
   - Ejecutar `main.tscn` y observar el debug UI para ver los scores

## Troubleshooting

### La acción no se ejecuta
- Verificar que `UtilityAiAgent.auto_execute_actions = true`
- Verificar que la acción tiene al menos una Consideration con score > 0
- Comprobar cooldown y `post_stop_block_time`

### El BT no termina
- Asegurarse de que la hoja escribe `"action_done"` en el blackboard al terminar
- Verificar que la condición de terminación en `tick()` es alcanzable

### Comportamiento erróneo
- Revisar que las hojas y actions usan la API pasiva del NPC (p. ej. `set_target()`, `consume_target_if_food()`, `start_eating()`, `get_closest_food()`).
- Verificar que el NPC expone las propiedades/estado necesarios (`is_eating`, `is_sleeping`, `has_food_in_pocked`, etc.) y los helpers (`has_target()`, `arrived()`, `get_closest_food()`).
- Usar prints en `before_run()` y `tick()` para debugging (y comprobar los writes en el blackboard `action_done`).

### Cambios muy frecuentes de acción
- Aumentar `sampling_interval` (ej: 0.5s)
- Aumentar `hysteresis_margin` (ej: 0.1)
- Añadir `cooldown` a las acciones (ej: 2.0s)

## Próximos Pasos Sugeridos

1. **Árboles más complejos**: añadir secuencias, paralelos, y decoradores en los BT.
2. **Consideraciones desde blackboard**: usar `consideration_from_blackboard.gd` para leer datos del BT.
3. **Interrupción de árboles**: implementar interrupciones parciales en ActionBT para comportamientos que pueden pausarse.
4. **Debugging avanzado**: integrar el visualizador de Beehave para inspeccionar árboles en runtime.

## Referencias

- [Utility AI documentation](../addons/utility_ai/README.md)
- [Beehave addon](../addons/beehave/)
- [Demo refactor con BT](../example_refactor/ai/BT_EXAMPLE_README.md)
