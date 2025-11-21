# CRÍTICO: Cambiar GraphDisplay de Node2D a Control

## Problema

El script `GraphDisplay.gd` ahora extiende `Control`, pero el nodo en la escena sigue siendo `Node2D`.

## Solución: Cambiar en el Editor de Godot

### Opción 1: Reemplazar el Nodo (RECOMENDADO)

1. **Abrir** `scenes/ui/SocialGraphPanel.tscn`

2. **Seleccionar** el nodo `Panel/VBoxContainer/SubViewportContainer/SubViewport/GraphDisplay`

3. **Click derecho** en el nodo → **Change Type**

4. **Buscar** "Control" en el diálogo

5. **Seleccionar** `Control` y click **Change**

6. **Reasignar el script**:

   - Con el nodo seleccionado
   - En el Inspector, asegurarse que el script sea `res://scripts/utils/graphs/visuals/GraphDisplay.gd`

7. **Verificar las propiedades exportadas** están asignadas:

   - `node_scene`: `res://scenes/ui/GraphNodeView.tscn`
   - `edge_scene`: `res://scenes/ui/GraphEdgeView.tscn`
   - `layout_type`: "circular"
   - `edge_label_mode`: "weight"

8. **Guardar** la escena (Ctrl+S)

---

### Opción 2: Recrear el Nodo

Si la Opción 1 no funciona:

1. **Eliminar** el nodo GraphDisplay actual

2. **Añadir** un nuevo nodo hijo a SubViewport:

   - Click derecho en SubViewport → Add Child Node
   - Buscar "Control"
   - Nombre: "GraphDisplay"

3. **Asignar el script**:

   - Con el nuevo nodo seleccionado
   - Arrastrar `res://scripts/utils/graphs/visuals/GraphDisplay.gd` al Inspector

4. **Configurar las propiedades** como en la Opción 1

5. **Guardar** la escena

---

## Verificación

Después del cambio, el árbol de nodos debe verse así:

```
SocialGraphPanel (Control)
└─ Panel (Panel)
   └─ VBoxContainer (VBoxContainer)
      └─ SubViewportContainer (SubViewportContainer)
         └─ SubViewport (SubViewport)
            ├─ Camera2D
            └─ GraphDisplay (Control) ← DEBE SER CONTROL
```

Si ves "GraphDisplay (Node2D)", el cambio no se aplicó correctamente.

---

## ¿Por qué Control en lugar de Node2D?

- `Control` tiene soporte nativo para `_gui_input()`
- `mouse_filter` funciona correctamente
- `accept_event()` es un método de Control
- Mejor integración con UI y SubViewport
- Acceso a propiedades como `size` para calcular viewport

---

## Si prefieres NO cambiar la escena

Puedo revertir el script a `Node2D`, pero perderás:

- Input handling mejorado
- Smooth zoom
- Better control de eventos de mouse

¿Prefieres que revierta o cambias el nodo en el editor?
