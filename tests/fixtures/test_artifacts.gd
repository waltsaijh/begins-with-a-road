extends RefCounted
## Local test output; excluded from version control and game exports.

static func path(relative_path: String) -> String:
	var output := "res://.godot/test-results/".path_join(relative_path)
	var error := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	assert(error == OK, "Cannot create test output directory: " + output.get_base_dir())
	return output
