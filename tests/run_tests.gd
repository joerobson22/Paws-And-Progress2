extends SceneTree
## Headless test runner: godot --headless --path . -s tests/run_tests.gd
## Runs every test_* method in tests/test_*.gd and exits non-zero on failure.


func _initialize() -> void:
	var failures := 0
	var passed := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files()).filter(func(f): return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()
	for file in files:
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failures += 1
			printerr("FAIL %s doesn't compile" % file)
			continue
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.call(name)
			if case.failures.is_empty():
				passed += 1
			else:
				failures += 1
				for f in case.failures:
					printerr("FAIL %s::%s  %s" % [file, name, f])
	print("%d passed, %d failed" % [passed, failures])
	quit(1 if failures > 0 else 0)
