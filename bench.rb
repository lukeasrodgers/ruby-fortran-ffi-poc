require 'ffi'
require 'benchmark'

module Flib
  extend FFI::Library
  ffi_lib 'ffi_multarray.dylib'
  attach_function :__exports_MOD_sum_arr, [ :pointer, :int ], :int
  attach_function :__exports_MOD_dot_prod, [ :pointer, :pointer, :int ], :int
end

a = (1..1_000_000).to_a

Benchmark.bmbm do |bm|
  bm.report('fortran') do
    arr_ptr = FFI::MemoryPointer.new(:int, a.size)
    arr_ptr.write_array_of_int(a)
    Flib.__exports_MOD_sum_arr(arr_ptr, a.size)
  end

  bm.report('ruby') do
    a.reduce(:+)
  end
end

b = (1..80).to_a
require 'matrix'

Benchmark.bmbm do |bm|
  bm.report('fortran') do
    dot_prod_arr1 = FFI::MemoryPointer.new(:int, 80)
    dot_prod_arr2 = FFI::MemoryPointer.new(:int, 80)
    dot_prod_arr1.write_array_of_int(b)
    dot_prod_arr2.write_array_of_int(b)
    Flib.__exports_MOD_dot_prod(dot_prod_arr1, dot_prod_arr2, 80)
  end

  bm.report('ruby') do
    Vector.elements(b).inner_product(Vector.elements(b))
  end
end
