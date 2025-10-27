@tool
extends Node
class_name TestSuiteBase

var test_prefix: String = "TestSuite"
var _tests: Array[Dictionary] = []

## Registra una prueba para ejecutarla más tarde.
func add_test(callable: Callable, test_name: String = "") -> void:
	if callable == null:
		push_warning("[%s] add_test: callable is null" % test_prefix)
		return
	if not callable.is_valid():
		push_warning("[%s] add_test: callable is invalid" % test_prefix)
		return
	var resolved_name: String = test_name
	if resolved_name.strip_edges() == "":
		resolved_name = String(callable.get_method())
	_tests.append({
		"callable": callable,
		"name": resolved_name
	})

## Elimina todas las pruebas registradas.
func clear_tests() -> void:
	_tests.clear()

## Ejecuta todas las pruebas registradas e imprime sus resultados.
func run_all_tests() -> void:
	var total := _tests.size()
	if total == 0:
		push_warning("[%s] No tests registered" % test_prefix)
		return
	var passed := 0
	for entry in _tests:
		var callable: Callable = entry.get("callable")
		var outcome: Dictionary
		if callable and callable.is_valid():
			outcome = callable.call()
		else:
			var fallback_name: String = str(entry.get("name", "Unnamed"))
			outcome = make_result(fallback_name, false, "Callable is invalid")
		var test_name: String = str(outcome.get("name", entry.get("name", "Unnamed")))
		if outcome.get("passed", false):
			passed += 1
			print("[%s][PASS] %s" % [test_prefix, test_name])
		else:
			push_error("[%s][FAIL] %s -> %s" % [test_prefix, test_name, outcome.get("details", "")])
	print("[%s] %d/%d tests passed" % [test_prefix, passed, total])

## Crea un diccionario de resultado con un formato estándar.
func make_result(label: String, passed: bool, details: String = "") -> Dictionary:
	return {
		"name": label,
		"passed": passed,
		"details": details if not passed else ""
	}

## Aserción genérica para pruebas booleanas.
func assert_true(condition: bool, label: String, details: String = "") -> Dictionary:
	return make_result(label, condition, details if not condition else "")

## Aserción genérica para comparar valores.
func assert_equal(expected, value, label: String) -> Dictionary:
	var passed: bool = expected == value
	var detail: String = "" if passed else "Expected %s, got %s" % [str(expected), str(value)]
	return make_result(label, passed, detail)

## Aserción para comparar flotantes dentro de una tolerancia.
func assert_float_approx(expected: float, value: float, tolerance: float, label: String) -> Dictionary:
	var diff: float = abs(expected - value)
	var passed: bool = diff <= tolerance
	var detail: String = "Expected %s ± %s, got %s" % [str(expected), str(tolerance), str(value)]
	return make_result(label, passed, detail)
