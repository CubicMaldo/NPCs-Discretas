@tool
extends TestSuiteBase

## Test suite for strongest_path algorithm implementation.

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	test_prefix = "StrongestPath"
	clear_tests()
	_register_tests()
	run_all_tests()


func _register_tests() -> void:
	add_test(Callable(self, "_test_simple_strongest_path"), "Simple strongest path")
	add_test(Callable(self, "_test_strongest_vs_shortest"), "Strongest path differs from shortest")
	add_test(Callable(self, "_test_no_path_exists"), "No path returns unreachable")
	add_test(Callable(self, "_test_direct_vs_indirect"), "Direct vs multi-hop paths")
	add_test(Callable(self, "_test_zero_weight_blocking"), "Zero weight blocks propagation")


func _test_simple_strongest_path() -> Dictionary:
	var graph := SocialGraph.new()
	# Simple path: 1 → 2 → 3
	# 1→2: 80, 2→3: 90
	# Expected strength: 0.8 * 0.9 = 0.72
	graph.connect_npcs(1, 2, 80.0)
	graph.connect_npcs(2, 3, 90.0)
	
	var result := graph.get_strongest_path(1, 3)
	graph.clear()
	
	if not result.get("reachable", false):
		return make_result("Simple strongest path", false, "Path not reachable")
	
	var path: Array = result.get("path", [])
	if path != [1, 2, 3]:
		return make_result("Simple strongest path", false, "Wrong path: %s" % [str(path)])
	
	var strength: float = result.get("strength", 0.0)
	var expected: float = 0.8 * 0.9
	return assert_float_approx(expected, strength, 0.01, "Simple strongest path")


func _test_strongest_vs_shortest() -> Dictionary:
	var graph := SocialGraph.new()
	# Create scenario where shortest != strongest:
	#   1 → 2 (weight: 50)
	#   2 → 3 (weight: 50)
	#   1 → 3 (weight: 90, direct)
	# Shortest: 1→3 (1 hop)
	# Strongest: 1→3 (0.9) vs 1→2→3 (0.5*0.5=0.25), so direct wins
	
	graph.connect_npcs(1, 2, 50.0)
	graph.connect_npcs(2, 3, 50.0)
	graph.connect_npcs(1, 3, 90.0)
	
	var result := graph.get_strongest_path(1, 3)
	graph.clear()
	
	if not result.get("reachable", false):
		return make_result("Strongest vs shortest", false, "Path not reachable")
	
	var path: Array = result.get("path", [])
	# Should choose direct path (1→3) as it's stronger
	if path != [1, 3]:
		return make_result("Strongest vs shortest", false, "Expected direct path, got: %s" % [str(path)])
	
	var strength: float = result.get("strength", 0.0)
	return assert_float_approx(0.9, strength, 0.01, "Strongest vs shortest")


func _test_no_path_exists() -> Dictionary:
	var graph := SocialGraph.new()
	graph.connect_npcs(1, 2, 80.0)
	graph.connect_npcs(3, 4, 70.0)
	# No path from 1 to 4
	
	var result := graph.get_strongest_path(1, 4)
	graph.clear()
	
	var reachable: bool = result.get("reachable", true)
	if reachable:
		return make_result("No path exists", false, "Should be unreachable")
	
	var path: Array = result.get("path", [])
	if not path.is_empty():
		return make_result("No path exists", false, "Path should be empty")
	
	return assert_true(true, "No path exists", "")


func _test_direct_vs_indirect() -> Dictionary:
	var graph := SocialGraph.new()
	# Scenario: 1→2→3 with high trust vs 1→3 direct with low trust
	#   1 → 2: 95
	#   2 → 3: 95
	#   1 → 3: 60 (direct)
	# Strongest: 1→2→3 (0.95*0.95=0.9025) > 1→3 (0.6)
	
	graph.connect_npcs(1, 2, 95.0)
	graph.connect_npcs(2, 3, 95.0)
	graph.connect_npcs(1, 3, 60.0)
	
	var result := graph.get_strongest_path(1, 3)
	graph.clear()
	
	if not result.get("reachable", false):
		return make_result("Direct vs indirect", false, "Path not reachable")
	
	var path: Array = result.get("path", [])
	# Should choose indirect path (1→2→3) as it's stronger
	if path != [1, 2, 3]:
		return make_result("Direct vs indirect", false, "Expected indirect path, got: %s" % [str(path)])
	
	var strength: float = result.get("strength", 0.0)
	var expected: float = 0.95 * 0.95
	return assert_float_approx(expected, strength, 0.01, "Direct vs indirect")


func _test_zero_weight_blocking() -> Dictionary:
	var graph := SocialGraph.new()
	# Path with zero-weight edge should block propagation
	#   1 → 2: 80
	#   2 → 3: 0  (no trust)
	#   1 → 4: 70
	#   4 → 3: 70
	
	graph.connect_npcs(1, 2, 80.0)
	graph.connect_npcs(2, 3, 0.0)
	graph.connect_npcs(1, 4, 70.0)
	graph.connect_npcs(4, 3, 70.0)
	
	var result := graph.get_strongest_path(1, 3)
	graph.clear()
	
	if not result.get("reachable", false):
		return make_result("Zero weight blocking", false, "Path not reachable")
	
	var path: Array = result.get("path", [])
	# Should use 1→4→3 since 2→3 has 0 weight
	if path != [1, 4, 3]:
		return make_result("Zero weight blocking", false, "Expected alternate path, got: %s" % [str(path)])
	
	var strength: float = result.get("strength", 0.0)
	var expected: float = 0.7 * 0.7
	return assert_float_approx(expected, strength, 0.01, "Zero weight blocking")
