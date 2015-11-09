require 'byebug'
require 'ffi'

module Hello
  extend FFI::Library
  ffi_lib 'ffi_multarray.dylib'
  # attach_function :multarray, [ :int ], :int
  attach_function :wont_set_out, [ :int, :int ], :void
  attach_function :assign_arr, [ :pointer ], :void
  # attach_function :return_arr_ptr, [ :pointer ], :pointer
end

# input = gets.chomp.to_i
# arr = [1,2,3,4]
x = 0
y = 1
v = Hello.wont_set_out(x, y)
puts "x: #{x}"
puts "y: #{y}"
puts "v: #{v}"

ptr = FFI::MemoryPointer.new(:int, 5)
Hello.assign_arr(ptr)
int_ptr = ptr.read_pointer

puts "int_ptr read_array_of_int: #{int_ptr.read_array_of_int(5)}"

# Every now and then we get this error:
# int_ptr read_array_of_int: [1, 2, 3, 4, 5]
# ruby(28078,0x7fff7c3d3300) malloc: *** error for object 0x6: pointer being freed was not allocated
# *** set a breakpoint in malloc_error_break to debug
# Abort trap: 6
