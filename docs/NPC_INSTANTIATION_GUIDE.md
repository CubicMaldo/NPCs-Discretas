# Guía Rápida: Cómo Instanciar NPCs Correctamente

## ⚠️ Problema Común

Los NPCs creados con `NPC.new()` no funcionarán correctamente si no se añaden al árbol de escena, porque `_ready()` nunca se ejecuta y el `SocialComponent` no se inicializa.

## ✅ Solución: Flujo Correcto de Instanciación

### Paso a Paso

```gdscript
# 1. Crear el NPC
var npc := NPC.new()

# 2. Configurar propiedades ANTES de añadir al árbol
npc.npc_id = 1
npc.npc_name = "Guard"
npc.name = "Guard"  # Nombre del nodo en el árbol de escena

# 3. Inyectar sistemas ANTES de añadir al árbol (importante!)
npc.social_graph_manager = social_manager

# 4. Añadir al árbol de escena (esto ejecuta _ready())
add_child(npc)

# 5. Esperar un frame para asegurar que _ready() completó
await get_tree().process_frame

# 6. Ahora el NPC está completamente inicializado y listo para usar
print("NPC ready:", npc.social_component != null)  # true
```

## 🔍 ¿Por Qué Este Orden?

### Qué pasa en `_ready()`
```gdscript
func _ready() -> void:
    current_position = global_position
    current_emotion = _instantiate_emotion()
    social_component = _ensure_social_component()  # ← Se crea aquí
    social_component.owner_id = npc_id
    if social_graph_manager:  # ← Usa el que inyectaste antes
        social_component.set_graph_manager(social_graph_manager)
```

### Problema si no inyectas sistemas antes
Si no inyectas `social_graph_manager` antes de `add_child()`:
- `_ready()` se ejecuta
- `social_component` se crea
- Pero `social_graph_manager` es `null`
- El component no se registra en el grafo
- Las consultas fallarán silenciosamente devolviendo 0.0

### Problema si no esperas el frame
Si intentas usar el NPC inmediatamente después de `add_child()`:
- `_ready()` podría no haberse ejecutado todavía
- `social_component` todavía es `null`
- Obtendrás errores de "null reference"

## 📋 Checklist de Instanciación

- [ ] `var npc := NPC.new()`
- [ ] Configurar `npc_id`, `npc_name`, `name`
[ ] Inyectar `social_graph_manager` (y opcionalmente un sistema de decisión proporcionado por un addon)
- [ ] `add_child(npc)`
- [ ] `await get_tree().process_frame`
- [ ] Ahora puedes usar el NPC

## 💡 Ejemplos Completos

### Ejemplo 1: NPC Simple
```gdscript
func create_npc(id: int, npc_name: String) -> NPC:
    var npc := NPC.new()
    npc.npc_id = id
    npc.npc_name = npc_name
    npc.name = npc_name
    npc.social_graph_manager = social_manager
    
    add_child(npc)
    await get_tree().process_frame
    
    # Registrar en el grafo con metadata
    social_manager.ensure_npc(npc)
    
    return npc

# Uso
var guard = await create_npc(1, "Guard")
var merchant = await create_npc(2, "Merchant")

# Crear relación
guard.social_component.set_relationship(merchant, 0.7)
print("Familiarity: ", guard.get_familiarity(merchant))
```

### Ejemplo 2: Múltiples NPCs con Batch
```gdscript
func create_multiple_npcs(count: int) -> Array[NPC]:
    var npcs: Array[NPC] = []
    
    # Crear todos los NPCs primero
    for i in range(count):
        var npc := NPC.new()
        npc.npc_id = i
        npc.npc_name = "NPC_%d" % i
        npc.name = "NPC_%d" % i
        npc.social_graph_manager = social_manager
        
        add_child(npc)
        npcs.append(npc)
    
    # Esperar un solo frame para todos
    await get_tree().process_frame
    
    # Registrar todos en el grafo
    for npc in npcs:
        social_manager.ensure_npc(npc)
    
    return npcs

# Uso
var npcs = await create_multiple_npcs(10)
print("Created %d NPCs" % npcs.size())
```

### Ejemplo 3: Con Metadata Rica
```gdscript
func create_npc_with_metadata(id: int, npc_name: String, role: String, faction: String) -> NPC:
    var npc := NPC.new()
    npc.npc_id = id
    npc.npc_name = npc_name
    npc.name = npc_name
    npc.social_graph_manager = social_manager
    
    add_child(npc)
    await get_tree().process_frame
    
    # Crear metadata rica
    var meta := NPCVertexMeta.new()
    meta.id = id
    meta.display_name = npc_name
    meta.role = role
    meta.faction = faction
    meta.level = randi_range(1, 10)
    meta.custom_data["created_at"] = Time.get_ticks_msec()
    
    social_manager.ensure_npc(npc, meta)
    
    return npc

# Uso
var guard = await create_npc_with_metadata(1, "Guard", "warrior", "city_watch")
var merchant = await create_npc_with_metadata(2, "Merchant", "trader", "traders_guild")
```

### Ejemplo 4: Desde Escena Preconstruida
Si tu NPC ya está en una escena `.tscn`:

```gdscript
func spawn_npc_from_scene(scene_path: String, id: int, pos: Vector2) -> NPC:
    var scene = load(scene_path)
    var npc: NPC = scene.instantiate()
    
    # Configurar antes de añadir
    npc.npc_id = id
    npc.social_graph_manager = social_manager
    npc.global_position = pos
    
    add_child(npc)
    await get_tree().process_frame
    
    # El NPC ya tiene su SocialComponent configurado desde _ready()
    social_manager.ensure_npc(npc)
    
    return npc

# Uso
var guard = await spawn_npc_from_scene("res://scenes/npcs/guard.tscn", 1, Vector2(100, 100))
```

## 🐛 Errores Comunes y Soluciones

### Error: "Invalid call. Nonexistent function 'get_familiarity'"
**Causa:** `social_component` es `null` porque `_ready()` no se ejecutó
**Solución:** Asegúrate de llamar `add_child()` y esperar un frame

### Error: Familiaridad siempre devuelve 0.0
**Causa:** `social_graph_manager` no fue inyectado antes de `add_child()`
**Solución:** Inyecta el manager ANTES de añadir al árbol

### Error: NPCs no aparecen en pantalla
**Causa:** NPCs no tienen Sprite2D o no configuraste `global_position`
**Solución:** 
```gdscript
npc.global_position = Vector2(100, 100)
# o añade un Sprite2D child
```

### Advertencia: "owner_key is null"
**Causa:** `npc_id` no fue configurado o es -1
**Solución:** Configura `npc_id` antes de usar el social_component

## 🎯 Best Practices

1. **Siempre inyecta sistemas antes de `add_child()`**
   ```gdscript
   npc.social_graph_manager = social_manager  # ANTES
   add_child(npc)  # DESPUÉS
   ```

2. **Usa funciones helper para crear NPCs**
   - Encapsula la lógica en `create_npc()` 
   - Evita repetir el mismo código

3. **Espera el frame si necesitas usar el NPC inmediatamente**
   ```gdscript
   add_child(npc)
   await get_tree().process_frame
   # Ahora es seguro usar npc.get_familiarity()
   ```

4. **Registra NPCs en el grafo después de inicialización**
   ```gdscript
   await get_tree().process_frame
   social_manager.ensure_npc(npc, metadata)
   ```

5. **Usa `queue_free()` para cleanup**
   ```gdscript
   npc.queue_free()  # Remueve del árbol y libera memoria
   ```

## 📚 Archivos de Referencia

- `scripts/entities/NPC.gd` - Implementación completa del NPC
- `scripts/entities/SocialComponent.gd` - Componente social
- `scripts/examples/example_usage.gd` - Ejemplos actualizados y funcionales

## 🚀 Próximo Paso

Una vez que entiendas este flujo, estás listo para:
1. Implementar Utility AI (ver `docs/NEXT_STEPS_UTILITY_AI.md`)
2. Integrar con beehave para Behavior Trees
3. Crear sistemas más complejos

---

**Resumen en una línea:**
`NPC.new()` → configurar → inyectar sistemas → `add_child()` → `await frame` → usar ✅
