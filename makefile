all: ruby_ffi

ruby_ffi:
	gfortran -dynamiclib ffi_multarray.f90 -o ffi_multarray.dylib
