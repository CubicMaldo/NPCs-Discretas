class_name BehaviorSystem
extends Node

signal action_chosen(npc, action)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
@export var debug_mode: bool = false

# Tunable base weights and multipliers with named constants for clarity and easier tuning
const BASE_WEIGHT_INTERACT := 1.0
const BASE_WEIGHT_WALK := 1.0
const BASE_WEIGHT_IGNORE := 1.0
const AFFINITY_INTERACT_BONUS := 1.5
const AFFINITY_INTERACT_MEDIUM := 0.75
const EMOTION_INT_MULT := 1.25

func _ready() -> void:
	rng.randomize()

# Allow tests to set RNG seed or inject a deterministic RNG
func set_random_seed(rng_seed: int) -> void:
	rng.seed = rng_seed

func set_rng(new_rng: RandomNumberGenerator) -> void:
	if new_rng:
		rng = new_rng

# Main entry: compute per-action scores (decoupled) then sample.
func choose_action_for(npc: NPC) -> String:
	if not npc:
		return "idle"

	var snapshot = npc.get_relationship_snapshot()
	var relationships: Dictionary = {}
	if typeof(snapshot) == TYPE_DICTIONARY:
		relationships = snapshot

	var strongest_affinity: float = _get_strongest_affinity_from_snapshot(relationships)
	var emotion_intensity: float = 0.0
	if npc.current_emotion:
		emotion_intensity = float(npc.current_emotion.intensity)

	var mods: Dictionary = _get_behavior_modifiers(npc)

	var interact_score: float = _score_interact(strongest_affinity, emotion_intensity, mods)
	var walk_score: float = _score_walk(emotion_intensity, mods)
	var ignore_score: float = _score_ignore(strongest_affinity, emotion_intensity, mods)

	var total: float = interact_score + walk_score + ignore_score
	if total <= 0.0:
		if debug_mode:
			print("BehaviorSystem: total score <= 0, returning idle for", npc)
		return "idle"

	var roll: float = rng.randf() * total
	var action: String = "idle"
	if roll < interact_score:
		action = "interact"
	elif roll < interact_score + walk_score:
		action = "walk"
	else:
		action = "ignore"

	if debug_mode:
		print("BehaviorSystem: npc=", npc, "scores: interact=", interact_score, "walk=", walk_score, "ignore=", ignore_score, "chosen=", action)
	action_chosen.emit(npc, action)
	return action

# Hook for other systems to listen for completed interactions.
func notify_interaction(_npc: NPC, _other: NPC) -> void:
	pass

func _score_interact(strongest_affinity: float, emotion_intensity: float, mods: Dictionary) -> float:
	var w: float = BASE_WEIGHT_INTERACT
	if strongest_affinity > 0.7:
		w += AFFINITY_INTERACT_BONUS
	elif strongest_affinity > 0.3:
		w += AFFINITY_INTERACT_MEDIUM
	w += max(emotion_intensity, 0.0) * EMOTION_INT_MULT
	if mods and mods.has("interact"):
		w *= float(mods["interact"])
	return max(w, 0.0)

func _score_walk(emotion_intensity: float, mods: Dictionary) -> float:
	var w: float = BASE_WEIGHT_WALK + (1.0 - abs(emotion_intensity)) * 0.5
	if mods and mods.has("walk"):
		w *= float(mods["walk"])
	return max(w, 0.0)

func _score_ignore(strongest_affinity: float, emotion_intensity: float, mods: Dictionary) -> float:
	var w: float = BASE_WEIGHT_IGNORE + max(-strongest_affinity, 0.0) * 1.5 + max(-emotion_intensity, 0.0) * 1.25
	if mods and mods.has("ignore"):
		w *= float(mods["ignore"])
	return max(w, 0.0)

func _get_strongest_affinity_from_snapshot(snapshot: Dictionary) -> float:
	var strongest := 0.0
	for value in snapshot.values():
		if typeof(value) == TYPE_OBJECT and value is Relationship:
			strongest = max(strongest, value.affinity)
		elif typeof(value) == TYPE_DICTIONARY:
			strongest = max(strongest, float(value.get("affinity", 0.0)))
		else:
			if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
				strongest = max(strongest, float(value))
	return strongest

func _get_behavior_modifiers(npc: NPC) -> Dictionary:
	var mods: Dictionary = {}
	if not npc:
		return mods
	if npc.personality and npc.personality.has_method("get_behavior_modifiers"):
		var m = npc.personality.get_behavior_modifiers()
		if typeof(m) == TYPE_DICTIONARY:
			mods = m
	return mods

func choose_state_for(npc: NPC) -> Resource:
	# Convenience: map choose_action_for result to a State Resource instance
	var action = choose_action_for(npc)
	match action:
		"interact":
			return preload("res://scripts/states/InteractState.gd").new()
		"walk":
			return preload("res://scripts/states/WalkState.gd").new()
		_:
			return preload("res://scripts/states/IdleState.gd").new()
