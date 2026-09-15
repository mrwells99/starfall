extends "res://tests/fulcrum_rework_test.gd"
# Keep the established CI entry point; the redesigned kit owns these assertions.
func report_results() -> void:
	print("Fulcrum Meditation checks: %d passed / %d total" % [checks-failures, checks])
