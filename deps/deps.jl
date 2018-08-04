# This is an auto-generated file; do not edit

# Pre-hooks
using Libdl

# Macro to load a library
macro checked_lib(libname, path)
    (Libdl.dlopen_e(path) == C_NULL) && error("Unable to load \n\n$libname ($path)\n\nPlease re-run Pkg.build(package), and restart Julia.")
    quote const $(esc(libname)) = $path end
end

# Load dependencies
@checked_lib liblmdb "liblmdb.so"

# Load-hooks

