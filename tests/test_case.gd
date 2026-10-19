class_name TestCase
extends RefCounted
## Minimal assertion helpers for the headless test runner.

var failures: PackedStringArray = []


func check(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append(message if message != "" else "check failed")


func eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])


func load_json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
