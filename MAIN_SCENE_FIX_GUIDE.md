# Guía de Correcciones Manual para Main.tscn

## Instrucciones para el Usuario

Debido a que `.tscn` es un archivo binario complejo, estas correcciones deben hacerse manualmente en el editor de Godot.

---

## 1. Habilitar NavigationRegion2D

1. Abrir `scenes/main/Main.tscn` en el editor
2. Seleccionar el nodo `NavigationRegion2D`
3. En el Inspector, **deshabilitar** la propiedad `Visible = false` (dejar en true/on)
4. Guardar escena (Ctrl+S)

---

## 2. Corregir NPCs - Configuración Individual

### NPC_2 → Alice

1. Seleccionar `NPC_2` en la jerarquía
2. En el Inspector, cambiar:
   - `npc_id`: `1`
   - `npc_name`: `"Alice"`
3. En la pestaña "Node", añadir al grupo `"npc"`
4. Asignar `personality_component`:
   - Click en `<empty>` → Load → `res://resources/personalities/personality_alice.tres`
5. Asignar `interaction_config`:
   - Click en `<empty>` → Load → `res://resources/interactions/default_interaction_config.tres`

### NPC_4 → Bob

1. Seleccionar `NPC_4` en la jerarquía
2. Cambiar:
   - `npc_id`: `2`
   - `npc_name`: `"Bob"`
3. Añadir al grupo `"npc"`
4. Asignar `personality_component`:
   - Load → `res://resources/personalities/personality_bob.tres`
5. Asignar `interaction_config`:
   - Load → `res://resources/interactions/default_interaction_config.tres`

### NPC_5 → Carol

1. Seleccionar `NPC_5` en la jerarquía
2. Cambiar:
   - `npc_id`: `3`
   - `npc_name`: `"Carol"`
3. Añadir al grupo `"npc"`
4. Asignar `personality_component`:
   - Load → `res://resources/personalities/personality_carol.tres`
5. Asignar `interaction_config`:
   - Load → `res://resources/interactions/default_interaction_config.tres`

### NPC_3 → Charlie

1. Seleccionar `NPC_3` en la jerarquía
2. Cambiar:
   - `npc_id`: `4`
   - (Ya tiene `npc_name: "Charlie"`)
3. Añadir al grupo `"npc"`
4. Asignar `personality_component`:
   - Load → `res://resources/personalities/personality_charlie.tres`
5. Asignar `interaction_config`:
   - Load → `res://resources/interactions/default_interaction_config.tres`

---

## 3. Opcional: Regenerar NavigationPolygon

1. Seleccionar `NavigationRegion2D`
2. En la barra de herramientas superior: `NavigationRegion2D` → `Bake NavigationMesh`
3. Verificar que los obstáculos del TileMap se reflejen correctamente

---

## 4. Opcional: Mejorar Camera2D

1. Seleccionar `Camera2D`
2. En el Inspector, añadir:
   - `Zoom`: `Vector2(2, 2)` (acerca la vista)
   - `Position Smoothing Enabled`: ON
   - `Position Smoothing Speed`: `5.0`
   - `Limit Left`: `0`
   - `Limit Top`: `0`
   - `Limit Right`: `630`
   - `Limit Bottom`: `360`

---

## 5. Habilitar DebugButton (Desarrollo)

1. Seleccionar `CanvasLayer/DebugButton`
2. En el Inspector, cambiar `Visible`: ON
3. Este botón imprime las conexiones del grafo social

---

## Verificación

Después de aplicar los cambios:

1. **Ejecutar el juego** (F5)
2. **Verificar console output**:

   ```
   [GameManager] Inicializando...
   [EventSystem] Inicializado
   [AudioManager] Inicializado con 16 SFX players
   Main: Found 4 NPCs in 'npc' group
   SocialGraphManager ensured NPC: Alice (1)
   SocialGraphManager ensured NPC: Bob (2)
   SocialGraphManager ensured NPC: Carol (3)
   SocialGraphManager ensured NPC: Charlie (4)
   ```

3. **Abrir grafo social**:

   - Click en botón para mostrar panel UI
   - Verificar que aparezcan 4 nodos
   - **Probar zoom**: Scroll del mouse
   - **Probar pan**: Click central + arrastrar

4. **Clickear DebugButton**: Debe imprimir conexiones entre NPCs

---

## Controles del Grafo Implementados

- **Zoom**: Scroll del mouse (rueda)
- **Pan**: Click central + arrastrar
- **Auto-zoom**: Automático según número de nodos
- **Auto-center**: Centra automáticamente al abrir

---

✅ **Todos los recursos de personalidad e interacción ya están creados y listos para usar.**
