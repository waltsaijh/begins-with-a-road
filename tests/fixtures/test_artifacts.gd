extends RefCounted
## Local test output; excluded from version control and game exports.

static func path(relative_path: String) -> String:
	# Exported Web's res:// is read-only; browser artifacts use its private FS.
	var directory := "user://test-results/" if OS.has_feature("web") else "res://.godot/test-results/"
	var output := directory.path_join(relative_path)
	var error := DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	assert(error == OK, "Cannot create test output directory: " + output.get_base_dir())
	return output
