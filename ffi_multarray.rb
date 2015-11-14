require 'byebug'
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
  attach_function :__exports_MOD_ret_p, [:int, :int], :pointer
  # attach_function :ret_p, [:int, :int], :pointer
  attach_function :__exports_MOD_sub_p, [:int, :int, :pointer], :void
  attach_function :__exports_MOD_sub_p_arr, [:int, :int, :pointer], :void
  # attach_function :return_arr_ptr, [ :pointer ], :pointer
  attach_function :ret_p_loc, [ :int, :int ], :int
  attach_function :sub_p_two, [ :int, :int ], :void
  attach_function :ret_cgpoint, [ :int, :int ], Point.by_ref
end

module Clib
  extend FFI::Library
  ffi_lib 'cpoint.dylib'
  attach_function :get_cpoint, [ :int, :int ], CPoint.by_ref
  attach_function :bad_cpoint, [ :int, :int ], CPoint.by_ref
end

ptr = FFI::MemoryPointer.new(:int, 5)
Hello.assign_arr(ptr)
int_ptr = ptr.read_pointer
puts "int_ptr read_array_of_int: #{int_ptr.read_array_of_int(5)}"

x = Hello.ret_i()
puts "x: #{x}"

# segfaults
# n = Hello.ret_cgpoint(1,2)

point_ptr = FFI::MemoryPointer.new(Point, 1)
# point_ptr = FFI::MemoryPointer.new(:int, 2)
# p = Point.new(point_ptr)
Hello.__exports_MOD_sub_p(4,84, point_ptr)
p = Point.new(point_ptr.read_pointer)
puts point_ptr
puts "p: #{p}, #{p[:x]}, #{p[:y]}"

# `size` will be called on Point, allocate space for 2 point objects, 
# `true` to zero the memory
# This will still occasionally crash, though not segfault, with this error:
# `ruby(61026,0x7fff7c3d3300) malloc: *** error for object 0x2: pointer being freed was not allocated`
# I believe this is due to the "free after memory pointer goes out of scope" behaviour.
point_ptr_arr = FFI::MemoryPointer.new(Point, 2, true)
Hello.__exports_MOD_sub_p_arr(4,7, point_ptr_arr)
p2 = Point.new(point_ptr_arr.read_pointer)
puts "p2: #{p2}, #{p2[:x]}, #{p2[:y]}"
p3 = Point.new(point_ptr_arr.read_pointer + Point.size)
puts "p3: #{p3}, #{p3[:x]}, #{p3[:y]}"

# segfaults
# Hello.__exports_MOD_ret_p(1,2)

# cp = Clib.get_cpoint(3, 4)
# puts "cp: #{cp[:x]}, #{cp[:y]}"

# this doesn't segfault, just returns junk data
# or, it occasionally segfaults?
# bad_cp = Clib.bad_cpoint(4, 5)
# puts "bad_cp: #{bad_cp[:x]}, #{bad_cp[:y]}"

# segfaults even though it doesn't return/interact with cpoint
# Hello.sub_p_two(4,5)

# segfaults even though we just return in, unrelated to pointer
# x = Hello.ret_p_loc(1,2)

# Every now and then we get this error:
# int_ptr read_array_of_int: [1, 2, 3, 4, 5]
# ruby(28078,0x7fff7c3d3300) malloc: *** error for object 0x6: pointer being freed was not allocated
# *** set a breakpoint in malloc_error_break to debug
# Abort trap: 6
