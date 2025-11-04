## Smoke test para verificar el sistema de metadata basado en Resources.
@tool
extends Node

func _ready() -> void:
	print("=== RESOURCE METADATA SMOKE TEST ===\n")
	
	var initial_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	print("Initial object count: %d\n" % initial_objects)
	
	test_resource_metadata()
	test_custom_data()
	test_serialization()
	test_metadata_persistence()
	
	var final_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var leaked_objects = final_objects - initial_objects
	
	print("\n=== ALL METADATA TESTS PASSED ===")
	print("Final object count: %d" % final_objects)
	print("Objects leaked: %d" % leaked_objects)
	
	if leaked_objects > 50:
		push_warning("Possible memory leak: %d objects not freed" % leaked_objects)


func test_resource_metadata() -> void:
	print("TEST 1: Resource-based metadata")
	var graph := SocialGraph.new()
	var npc := NPC.new()
	npc.npc_id = 1
	npc.name = "TestNPC"
	
	# Crear metadata tipada
	var meta := NPCVertexMeta.new()
	meta.role = "warrior"
	meta.faction = "kingdom"
	meta.level = 10
	
	graph.ensure_npc(npc, meta)
	var vertex := graph.get_vertex_by_npc(npc)
	
	assert(vertex != null, "Vertex should exist")
	assert(vertex.meta is NPCVertexMeta, "Metadata should be NPCVertexMeta")
	
	var npc_meta := vertex.meta as NPCVertexMeta
	assert(npc_meta.role == "warrior", "Role should be 'warrior'")
	assert(npc_meta.faction == "kingdom", "Faction should be 'kingdom'")
	assert(npc_meta.level == 10, "Level should be 10")
	
	print("  ✓ Resource metadata works correctly")
	print("    - role: %s" % npc_meta.role)
	print("    - faction: %s" % npc_meta.faction)
	print("    - level: %d" % npc_meta.level)
	npc.free()
	graph.clear()


func test_custom_data() -> void:
	print("\nTEST 2: Custom data in Resource metadata")
	var graph := SocialGraph.new()
	var npc := NPC.new()
	npc.npc_id = 2
	npc.name = "MageNPC"
	
	# Usar Resource con custom_data
	var meta := NPCVertexMeta.new()
	meta.role = "mage"
	meta.faction = "wizards"
	meta.level = 15
	meta.custom_data["spell_power"] = 100
	meta.custom_data["mana"] = 500
	
	graph.ensure_npc(npc, meta)
	var vertex := graph.get_vertex_by_npc(npc)
	
	assert(vertex != null, "Vertex should exist")
	assert(vertex.meta is NPCVertexMeta, "Metadata should be NPCVertexMeta")
	
	var npc_meta := vertex.meta as NPCVertexMeta
	assert(npc_meta.role == "mage", "Role should be 'mage'")
	assert(npc_meta.custom_data.has("spell_power"), "Custom data should have spell_power")
	assert(npc_meta.custom_data["spell_power"] == 100, "Spell power should be 100")
	
	print("  ✓ Resource with custom data works")
	print("    - role: %s" % npc_meta.role)
	print("    - faction: %s" % npc_meta.faction)
	print("    - level: %d" % npc_meta.level)
	print("    - custom_data.spell_power: %d" % npc_meta.custom_data.get("spell_power"))
	print("    - custom_data.mana: %d" % npc_meta.custom_data.get("mana"))
	npc.free()
	graph.clear()


func test_serialization() -> void:
	print("\nTEST 3: Serialization with Resource metadata")
	var graph := SocialGraph.new()
	
	# Crear NPCs con metadata tipada
	var meta1 := NPCVertexMeta.new()
	meta1.id = 10
	meta1.display_name = "Hero"
	meta1.role = "hero"
	meta1.faction = "alliance"
	meta1.level = 20
	
	var meta2 := NPCVertexMeta.new()
	meta2.id = 11
	meta2.display_name = "Villain"
	meta2.role = "villain"
	meta2.faction = "horde"
	meta2.level = 25
	
	graph.ensure_npc(10, meta1)
	graph.ensure_npc(11, meta2)
	graph.connect_npcs(10, 11, 50.0)
	
	# Serializar
	var data := graph.serialize()
	assert(data.has("nodes"), "Serialized data should have nodes")
	assert(data.has("edges"), "Serialized data should have edges")
	
	print("  ✓ Serialization includes metadata")
	print("    - nodes count: %d" % data["nodes"].size())
	
	# Deserializar
	var graph2 := SocialGraph.new()
	var success := graph2.deserialize(data)
	assert(success, "Deserialization should succeed")
	
	var vertex = graph2.get_vertex(10)
	assert(vertex != null, "Vertex should exist after deserialization")
	assert(vertex.meta is NPCVertexMeta, "Metadata should be NPCVertexMeta")
	
	var restored_meta := vertex.meta as NPCVertexMeta
	assert(restored_meta.display_name == "Hero", "Display name should be restored")
	assert(restored_meta.role == "hero", "Role should be restored")
	assert(restored_meta.level == 20, "Level should be restored")
	assert(restored_meta.loaded_from_save == true, "loaded_from_save should be true")
	
	print("  ✓ Deserialization restores Resource metadata")
	print("    - restored display_name: %s" % restored_meta.display_name)
	print("    - restored role: %s" % restored_meta.role)
	print("    - restored level: %d" % restored_meta.level)
	print("    - loaded_from_save: %s" % str(restored_meta.loaded_from_save))
	
	graph.clear()
	graph2.clear()


func test_metadata_persistence() -> void:
	print("\nTEST 4: Metadata persistence across vertices")
	var graph := SocialGraph.new()
	
	# Crear múltiples NPCs con diferentes metadata
	var meta1 := NPCVertexMeta.new()
	meta1.role = "knight"
	meta1.level = 30
	meta1.faction = "royal_guard"
	graph.ensure_npc(20, meta1)
	
	var meta2 := NPCVertexMeta.new()
	meta2.role = "archer"
	meta2.level = 25
	meta2.faction = "hunters"
	graph.ensure_npc(21, meta2)
	
	# Verificar ambos existen con su metadata correcta
	var v20 = graph.get_vertex(20)
	var v21 = graph.get_vertex(21)
	
	assert(v20 != null and v21 != null, "Both vertices should exist")
	assert(v20.meta is NPCVertexMeta, "v20 meta should be NPCVertexMeta")
	assert(v21.meta is NPCVertexMeta, "v21 meta should be NPCVertexMeta")
	
	var m20 := v20.meta as NPCVertexMeta
	var m21 := v21.meta as NPCVertexMeta
	
	assert(m20.role == "knight" and m20.level == 30, "v20 metadata correct")
	assert(m21.role == "archer" and m21.level == 25, "v21 metadata correct")
	
	# Serializar y deserializar
	var data := graph.serialize()
	var graph2 := SocialGraph.new()
	var success := graph2.deserialize(data)
	
	assert(success, "Graph should serialize/deserialize")
	
	var v20_restored = graph2.get_vertex(20)
	var v21_restored = graph2.get_vertex(21)
	
	assert(v20_restored.meta is NPCVertexMeta, "v20 restored should be NPCVertexMeta")
	assert(v21_restored.meta is NPCVertexMeta, "v21 restored should be NPCVertexMeta")
	
	var m20_restored := v20_restored.meta as NPCVertexMeta
	var m21_restored := v21_restored.meta as NPCVertexMeta
	
	assert(m20_restored.role == "knight", "v20 role preserved")
	assert(m21_restored.role == "archer", "v21 role preserved")
	
	print("  ✓ Metadata persists correctly")
	print("    - Multiple NPCs with different metadata")
	print("    - Serialization preserves all fields")
	print("    - Deserialization restores correctly")
	
	graph.clear()
	graph2.clear()
