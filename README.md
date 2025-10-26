# Medieval Social Simulator (Godot 4.x)

## Resumen
- Simulación top-down centrada en dinámicas sociales entre NPCs en una aldea medieval.
- Relaciones entre NPCs se modelan como aristas ponderadas en un grafo social dinámico. El grafo mantiene un registro explícito de nodos y admite referencias a objetos `NPC` en tiempo de ejecución así como claves por `npc_id` (ints).

## Requisitos
- Godot Engine 4.5.

## Estado actual del grafo y comportamiento clave
- Implementación del grafo: `scripts/utils/Graph.gd` mantiene nodos (con metadatos) y una matriz de adyacencia; acepta claves por objeto (`NPC`) o por `npc_id`.
- Recursos auxiliares: `scripts/utils/Vertex.gd` y `scripts/utils/Edge.gd` están disponibles para modelar metadatos de vértices y aristas ponderadas.
- `SocialGraphManager` (`scripts/systems/SocialGraphManager.gd`) actúa como fachada/gestor del grafo en runtime. Está diseñado para trabajar con objetos `NPC` directamente y ofrece:
  - `register_interaction(a, b)`: hook que actualiza o crea la afinidad entre `a` y `b` (usa valores devueltos por `_evaluate_interaction_delta` en los NPCs si están disponibles).
  - `add_connection`, `remove_connection`, `get_relationships_for`: métodos compatibles con los consumidores del sistema (`RelationshipComponent`, `BehaviorSystem`, etc.).
  - Señal `interaction_registered` para observadores UI/analytics.

Este diseño permite que sistemas y UI trabajen con referencias a objetos en tiempo de ejecución (más convenientes para visualización y metadatos) mientras mantiene compatibilidad con APIs que usan ids numéricos.

## Estructura del proyecto (relevante)
- `scenes/` – escenas del juego (entrada, mundo, NPCs, UI).
- `scripts/core/` – orquestación (GameManager, TimeManager, EventSystem).
- `scripts/entities/` – `NPC.gd`, `RelationshipComponent.gd`, recursos `Personality`, `Emotion`, `Relationship`.
- `scripts/systems/` – `SocialGraphManager.gd`, `BehaviorSystem.gd`, etc.
- `scripts/utils/` – utilidades: `Graph.gd`, `GraphAlgorithms.gd` (placeholder para análisis), `Vertex.gd`, `Edge.gd`.

## Cómo usar el grafo en runtime
1. Añade una instancia de `SocialGraphManager` en la escena principal (o regístrala como singleton/autoload si prefieres).
2. Cuando instancies un `NPC`, llama `npc.set_systems(graph_manager, behavior_system)` para inyectar dependencias — esto registrará el nodo (objeto) en el grafo.
3. Para registrar interacciones, los NPCs llaman `interact_with(other_npc)`; internamente `SocialGraphManager.register_interaction(self, other_npc)` actualizará las afinidades.
4. `RelationshipComponent` mantiene un cache local y sincroniza con `SocialGraphManager` mediante `get_relationships_for(npc)` y `add_connection`/`remove_connection`.

## Notas para desarrolladores
- Vertex.meta: en `scripts/utils/Vertex.gd` el campo `meta` es un `Dictionary` para pares clave→valor (ej. `name`, `pos`, `ref`). Es útil en tiempo de ejecución para enlazar `ref` a nodos, pero evita serializar referencias a `Node` directamente si planeas guardar el grafo en disco — en su lugar guarda `npc_id` o `NodePath`.
- Compatibilidad: `Graph` acepta tanto objetos como ids. Internamente mantiene `id_to_ref` para mapear `npc_id` → objeto registrado. `get_relationships_for` devuelve claves por id cuando el vecino tiene `npc_id`.
- Señales: `SocialGraphManager.interaction_registered` se emite con los parámetros (a_key, b_key, affinity). `a_key`/`b_key` pueden ser objetos; si prefieres recibir id explícitos, se puede ampliar la señal para emitir `npc_id` y `ref`.

## Prueba rápida (sanity check)
1. Abrir el proyecto en Godot.
2. Asegúrate de que la escena principal contiene `SocialGraphManager` o regístralo como autoload.
3. Crea/instancia 2–3 NPCs en la escena y en su setup llama `set_systems(graph_manager, behavior_system)`.
4. En el inspector o desde un script llamador, ejecuta `npc_a.interact_with(npc_b)` varias veces.
5. Inspecciona `SocialGraphManager.adjacency` en tiempo de ejecución: deberías ver aristas entre los objetos (o sus ids) con pesos de afinidad crecientes. También puedes llamar `relationship = npc_a.get_relationship_snapshot()` para comprobar la sincronización local.

## Siguientes pasos recomendados
- Añadir utilidades de análisis en `scripts/utils/GraphAlgorithms.gd` (degree centrality, BFS/shortest path, detección de comunidades).
- Implementar `GraphVisualizer` (`scripts/ui/GraphVisualizer.gd`) para renderizar la red en tiempo real.
- Decidir si `RelationshipComponent` debe migrar a usar referencias a NPCs en vez de ids (mejor para runtime, más complejo para persistencia).
- Añadir tests/escenas de integración que creen NPCs, simulen interacciones y validen invariantes del grafo.

## Contribuyendo
1. Crea una rama por feature.
2. Mantén commits atómicos y documenta cambios complejos en comentarios y en este README si impactan la API.
3. Abre el proyecto en Godot 4.5 y verifica que no hay errores en el editor al guardar scripts.

Happy simulating!
