require 'fiddle'
require 'fiddle/struct'
require 'fiddle/cparser'

fortlib = Fiddle.dlopen('ffi_multarray.dylib')

# just returns an int
ret_i = Fiddle::Function.new(
  fortlib['ret_i'],
  [],
  Fiddle::TYPE_INT
)
puts ret_i.call

# allocate ara
assign_allocated_arr = Fiddle::Function.new(
  fortlib['assign_allocated_arr'],
  [Fiddle::TYPE_VOIDP],
  Fiddle::TYPE_VOID
)
a = []
assign_allocated_arr_ptr = Fiddle::Pointer.new(a.object_id << 1)
assign_allocated_arr.call(assign_allocated_arr_ptr.ref)
puts "null?: #{assign_allocated_arr_ptr.null?}"
assigned = (0..4).map { |i| assign_allocated_arr_ptr[i*Fiddle::SIZEOF_INT] }
puts "assigned: #{assigned}"


# allocate array in ruby, pass to Fortran, Fortran populates values
assign_arr = Fiddle::Function.new(
  fortlib['assign_arr'],
  [Fiddle::TYPE_VOIDP],
  Fiddle::TYPE_VOID
)
assign_arr_ptr = Fiddle::Pointer.malloc(5 * Fiddle::SIZEOF_INT)
assign_arr.call(assign_arr_ptr.ref)
assigned = (0..4).map { |i| assign_arr_ptr[i*Fiddle::SIZEOF_INT] }
puts "assigned: #{assigned}"



# return int sum of an array
sum_arr = Fiddle::Function.new(
  fortlib['__exports_MOD_sum_arr'],
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INT],
  Fiddle::TYPE_INT
)
ptr = Fiddle::Pointer.malloc(10 * Fiddle::SIZEOF_INT)
(1..10).to_a.each {|i| ptr[i*Fiddle::SIZEOF_INT] = i+1}
sum = sum_arr.call(ptr, 10)
puts "sum: #{sum}"

dot_prod = Fiddle::Function.new(
  fortlib['__exports_MOD_dot_prod'],
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INT],
  Fiddle::TYPE_INT
)
ptr1 = Fiddle::Pointer.malloc(50 * Fiddle::SIZEOF_INT)
(0..49).to_a.each {|i| ptr1[i*Fiddle::SIZEOF_INT] = i+1}
ptr2 = Fiddle::Pointer.malloc(50 * Fiddle::SIZEOF_INT)
(0..49).to_a.each {|i| ptr2[i*Fiddle::SIZEOF_INT] = i+1}
result = dot_prod.call(ptr1, ptr2, 50)
puts "dot product: #{result}"

include Fiddle::CParser
types, members = parse_struct_signature(['int x','int y'])
Point = Fiddle::CStructBuilder.create(Fiddle::CStruct, types, members)

point_ptr = Fiddle::Pointer.malloc(Point.size)
sub_p = Fiddle::Function.new(
  fortlib['__exports_MOD_sub_p'],
  [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
  Fiddle::TYPE_VOID
)

# Our Fortran subroutine takes a pointer to a memory address large enough to hold a Point from ruby,
# manipulates the values of a statically allocated Fortran point object, then returns a pointer to it.
# We treat point_ptr as a pointer to a pointer.
# Fiddle::SIZEOF_UINTPTR_T is 64 bits, size of ptr on i86 platform, unpack it appropriately
unpack_directive = Fiddle::SIZEOF_UINTPTR_T == 8 ? 'Q' : 'L'
sub_p.call(2, 16, point_ptr)
new_pointer = point_ptr[0, Fiddle::SIZEOF_UINTPTR_T].unpack(unpack_directive).first
point = Point.new(new_pointer)
puts point.x
puts point.y
