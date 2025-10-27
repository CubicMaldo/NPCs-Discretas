# Migration Guide (v1 ➜ v2)

## Key API Updates

### `ensure_npc`
- **Before**: Implicitly created nodes when calling most graph helpers with integer IDs.
- **Now**: Call `SocialGraphManager.ensure_npc(npc_or_id, meta)` when spawning NPCs.
- Provides lifecycle tracking (WeakRef registry + Dunbar enforcement).

### `register_interaction`
- Continues to accept objects or IDs but now normalises them through `ensure_npc` internally.
- Optional per-actor metadata can be supplied via `options = {"meta_a": {...}, "meta_b": {...}}`.

### `remove_npc`
- New helper to expunge a character (and its edges) from the social graph. Call when permanently despawning an NPC.

### Decay & Cleanup
- `SocialGraph.decay_rate_per_second` controls passive decay.
- Invoke `apply_decay(delta_seconds)` during time steps and `cleanup_invalid_nodes()` as part of world maintenance loops.

## Persistence Workflow

1. **Saving**
   ```gdscript
   var err := social_graph.save_to_file("user://social_graph.dat", true)
   if err != OK:
       push_error("Save failed: %s" % err)
   ```

2. **Loading**
   ```gdscript
   var err := social_graph.load_from_file("user://social_graph.dat")
   if err != OK:
       push_error("Load failed: %s" % err)
   ```

3. **Rebinding NPC Instances**
   ```gdscript
   for npc in spawned_npcs:
       social_graph.register_loaded_npc(npc)
   ```

## Validation & Repair
- Use `validate_graph()` to gather errors/warnings before or after load.
- Call `repair_graph()` to remove dangling edges, stale NPCs, or asymmetry introduced by legacy saves.

## Testing
- Open `scenes/tests/test_social_graph.tscn` and run the scene to execute the automated smoke tests defined in `scripts/tests/TestSocialGraph.gd`.

## Checklist
- [ ] Replace calls to the old `ensure_node()` helper with `ensure_npc()`.
- [ ] Call `register_loaded_npc()` after spawning NPC scenes during load.
- [ ] Remove manual NPC cleanup; rely on `remove_npc()` or tree lifecycle.
- [ ] Update save/load pipelines to handle compressed JSON via `save_to_file` / `load_from_file`.
- [ ] Schedule `apply_decay()` / `cleanup_invalid_nodes()` in time-management systems.
