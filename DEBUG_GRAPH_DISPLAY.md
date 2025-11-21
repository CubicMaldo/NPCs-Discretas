# Debug: Test Graph Display

Para probar la visualización del grafo, ejecuta lo siguiente en la consola de Godot:

```gdscript
# En main.gd, añade temporalmente al final de _ready():
func _ready():
    # ... código existente ...

    # DEBUG: Crear algunas conexiones de prueba
    await get_tree().create_timer(1.0).timeout

    var npcs = get_tree().get_nodes_in_group("npc")
    if npcs.size() >= 2:
        social_graph_manager.add_connection(npcs[0], npcs[1], 75.0)
        social_graph_manager.add_connection(npcs[1], npcs[0], 60.0)
        if npcs.size() >= 3:
            social_graph_manager.add_connection(npcs[0], npcs[2], 50.0)
            social_graph_manager.add_connection(npcs[2], npcs[1], 80.0)
        if npcs.size() >= 4:
            social_graph_manager.add_connection(npcs[3], npcs[0], 90.0)
            social_graph_manager.add_connection(npcs[1], npcs[3], 45.0)

        print("DEBUG: Created test connections between NPCs")
```

Esto asegura que haya conexiones visibles en el grafo.

## Verificaciones:

1. **Abrir panel**: Click en botón de toggle UI
2. **Ver console**: Buscar mensajes de `[GraphDisplay]`
3. **Verificar zoom**: Mensajes como "Zoom set to: 1.00"
4. **Verificar nodos**: "Graph has X nodes"

Si no ves nodos, verifica que:

- NPCs tienen grupo "npc" asignado
- NavigationRegion2D está visible
- SocialGraphManager está presente en la escena
