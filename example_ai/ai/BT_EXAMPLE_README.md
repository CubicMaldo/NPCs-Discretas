Ejemplo Utility→Behaviour Tree (demo sin dependencias externas)

Qué hace
- `ActionBT` (addons/utility_ai/actions/action_bt.gd) es una Action que carga un PackedScene que representa un Behaviour Tree o runner.
- En `example/ai/bt/` hay un runner mínimo (`nodes.gd`) y `eat_bt.tscn` que simula un BT que dura ~3s.
- `example/ai/actions/action_bt_example.tscn` es una escena que tiene la Action configurada con `eat_bt.tscn`.

Cómo probar
1. Abre `example/characters/npc.tscn` en el editor.
2. Añade un nuevo Action node bajo `UtilityAiAgent` (click derecho > Add Child Node > Node).
3. En el nuevo nodo, asigna el script `res://addons/utility_ai/actions/action_bt.gd`.
4. En el inspector del nodo, asigna `bt_scene` a `res://example/ai/bt/eat_bt.tscn`.
5. Opcional: activa `UtilityAiAgent.auto_execute_actions = true` para que el agente inicie acciones automáticamente.
6. Ejecuta la escena y observa en consola las señales `action_started` / `action_completed`.

Notas
- Si tienes instalado el addon `beehave` u otro runner de Behaviour Trees, puedes usar su PackedScene en `bt_scene` en vez del runner mínimo incluido aquí.
- `ActionBT` intenta llamar a `start()` / `run()` / `is_running()` / `stop()` en el BT instanciado; si tu runner usa API distinta, adapta mínimamente `action_bt.gd`.

Limitaciones
- Este ejemplo incluye un runner mínimo (`nodes.gd`) solo para demostración. Para uso productivo usa la implementación real de Behaviour Trees (por ejemplo beehave) y apunta `bt_scene` a tu PackedScene del árbol.
