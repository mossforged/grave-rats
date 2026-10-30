extends RefCounted
## Base for headless tests (extend by path: extends "res://tests/test_case.gd"). Any method named test_* runs; check() records failures.

var failures: PackedStringArray = []


func check(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond


func check_eq(got: Variant, want: Variant, msg: String) -> bool:
	return check(got == want, "%s (got %s, want %s)" % [msg, str(got), str(want)])
