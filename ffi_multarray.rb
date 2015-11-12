# require 'byebug'
require 'ffi'

class Point < FFI::Struct
  layout :x, :int,
    :y, :int
end

class CPoint < FFI::Struct
  layout :x, :int,
    :y, :int
end

module Hello
  extend FFI::Library
  ffi_lib 'ffi_multarray.dylib'
  # attach_function :multarray, [ :int ], :int
  attach_function :assign_arr, [ :pointer ], :void
  attach_function :ret_i, [], :int
  attach_function :ret_loc_i, [:int], :pointer
  # attach_function :ret_p, [:int, :int], Point.by_ref
  # attach_function :ret_p, [:int, :int], :pointer
  attach_function :sub_p, [:int, :int, Point.by_value], :void
  # attach_function :return_arr_ptr, [ :pointer ], :pointer
end

module Clib
  extend FFI::Library
  ffi_lib 'cpoint.dylib'
  attach_function :get_cpoint, [ :int, :int ], CPoint.by_ref
end

ptr = FFI::MemoryPointer.new(:int, 5)
Hello.assign_arr(ptr)
int_ptr = ptr.read_pointer
puts "int_ptr read_array_of_int: #{int_ptr.read_array_of_int(5)}"

x = Hello.ret_i()
puts "x: #{x}"

# point_ptr = FFI::MemoryPointer.new(Point, 1, false)
# point_ptr = FFI::MemoryPointer.new(:int, 2)
# p = Point.new
# Hello.sub_p(1,2, p)

cp = Clib.get_cpoint(3, 4)
puts "cp: #{cp[:x]}, #{cp[:y]}"

# Every now and then we get this error:
# int_ptr read_array_of_int: [1, 2, 3, 4, 5]
# ruby(28078,0x7fff7c3d3300) malloc: *** error for object 0x6: pointer being freed was not allocated
# *** set a breakpoint in malloc_error_break to debug
# Abort trap: 6
