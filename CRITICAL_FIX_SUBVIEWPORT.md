# INSTRUCCIONES CRÍTICAS: Corrección Manual del SubViewport

## Problema Identificado

El `SubViewport` en `SocialGraphPanel.tscn` tiene `handle_input_locally = false`, lo que bloquea los eventos de input al `GraphDisplay`.

## Solución: Editar en Godot Editor

1. **Abrir** `scenes/ui/SocialGraphPanel.tscn` en el editor de Godot

2. **Seleccionar** el nodo: `Panel/VBoxContainer/SubViewportContainer/SubViewport`

3. **En el Inspector**, buscar la propiedad **"Handle Input Locally"**

4. **Cambiar** de `false` (OFF) a `true` (ON)

5. **Guardar** la escena (Ctrl+S)

---

## Verificación Alternativa (Archivo .tscn)

Si prefieres editar el archivo directamente:

**Línea 64** en `scenes/ui/SocialGraphPanel.tscn`:

```gdscript
# ANTES:
handle_input_locally = false

# DESPUÉS:
handle_input_locally = true
```

---

## Después de Aplicar el Fix

**Controles del Grafo**:

- **Zoom**: Rueda del mouse (scroll)
- **Pan**: Click izquierdo + arrastrar
- **Rango de zoom**: 0.1x hasta 5.0x (mucho más amplio)

**Prueba**:

1. Ejecuta el juego
2. Abre el panel del grafo
3. Haz scroll para zoom out (deberías poder alejar MUCHO más)
4. Click izquierdo + arrastra para mover el grafo

Si los nodos siguen sin verse, verifica:

- Que los NPCs tengan el grupo "npc" asignado
- Que haya al menos una conexión entre NPCs (usa el DebugButton "Print Connections")
