extends SceneTree

func _init():
	print("Starting NPC Behavior Test...")
	
	# Create Mock SocialGraphManager
	var graph_manager = SocialGraphManager.new()
	root.add_child(graph_manager)
	
	# Create NPCs
	var npc1 = NPC.new(1, "NPC_1", graph_manager)
	var npc2 = NPC.new(2, "NPC_2", graph_manager)
	
	root.add_child(npc1)
	root.add_child(npc2)
	
	# Wait for _ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify Personality Component
	if npc1.personality_component:
		print("PASS: NPC1 has PersonalityComponent")
	else:
		print("FAIL: NPC1 missing PersonalityComponent")
		
	# Test Talk
	print("\nTesting Talk...")
	var initial_fam = npc1.get_familiarity(npc2)
	print("Initial Familiarity: ", initial_fam)
	
	npc1.talk_to(npc2)
	
	var after_talk_fam = npc1.get_familiarity(npc2)
	print("After Talk Familiarity: ", after_talk_fam)
	
	if after_talk_fam != initial_fam:
		print("PASS: Talk changed familiarity")
	else:
		print("FAIL: Talk did not change familiarity (could be 0 change if bad luck, but unlikely with default settings)")

	# Test Fight
	print("\nTesting Fight...")
	npc1.fight_with(npc2)
	
	var after_fight_fam = npc1.get_familiarity(npc2)
	print("After Fight Familiarity: ", after_fight_fam)
	
	if after_fight_fam < after_talk_fam:
		print("PASS: Fight decreased familiarity")
	else:
		print("FAIL: Fight did not decrease familiarity")

	print("\nTest Complete.")
	quit()
