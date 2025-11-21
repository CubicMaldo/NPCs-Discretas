# CRÍTICO: Deshabilitar Input en Edges y Nodes

Los nodos y aristas del grafo están capturando eventos de mouse, bloqueando el zoom y pan.

## Solución: Configurar Mouse Filter

### Opción 1: En las escenas (RECOMENDADO)

**Para GraphEdgeView.tscn**:

1. Abrir `scenes/ui/GraphEdgeView.tscn`
2. Seleccionar el nodo raíz (probablemente Line2D o Node2D)
3. En Inspector → CanvasItem → Mouse → **Mouse Filter**
4. Cambiar a **"Ignore"**
5. Guardar

**Para GraphNodeView.tscn**:

1. Abrir `scenes/ui/GraphNodeView.tscn`
2. Seleccionar el nodo raíz
3. Mismo cambio: **Mouse Filter = "Ignore"**
4. Guardar

### Opción 2: Programática (si las escenas tienen scripts)

Si `GraphEdgeView` o `GraphNodeView` tienen scripts asociados, añadir en `_ready()`:

```gdscript
func _ready():
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    # o si es Node2D:
    # set_process_input(false)
```

## Verificación

Después del fix:

- Zoom should work both in and out
- Pan should work even cuando hay edges
- Auto-zoom debería ejecutarse al abrir panel

## Debug

Ejecuta el juego y busca en consola:

```
[GraphDisplay] Scheduling auto-zoom for X nodes
[GraphDisplay] Applying deferred auto-zoom for X nodes
[GraphDisplay] Zoom IN/OUT at ...
```

Si no ves estos mensajes, el input está siendo bloqueado por los children.
