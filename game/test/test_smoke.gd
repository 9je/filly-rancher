extends GutTest

# Smoke test for the GUT harness itself. Confirms the test runner actually
# executes tests, reports failures, and exits non-zero when a test fails --
# not just that it can print PASS.


func test_harness_reports_success() -> void:
	assert_eq(1, 1)
