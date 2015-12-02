This experimental code is an attempted proof-of-concept for ruby calling Fortran code
via the [ruby ffi](https://github.com/ffi/ffi) library and Fiddle from ruby stdlib. There is also
some simple C code called via FFI and Fiddle, though it was mostly written just to figure out
how to get the Fortran interop working.

This code runs on OSX and gfortran 5.1.0 -- I have no idea if it will work with other setups.

My familiarity with both ruby-ffi, Fiddle, and Fortran (and C!) is very limited, so there are probably many
mistakes and errors of understanding here.

My goal was to figure out how to use Fortran subroutines and/or functions to be callable from
ruby, and manipulate and return data. After a lot of experimentation and segfaults, here 
are a few approaches I was able to get *mostly* working.

The following code snippets leave off some of the ruby-ffi/Fiddle/Fortran boilerplate, which you can get
from the src in this repo. It assumes a ruby module named Flib (ffi) or fortlib (Fiddle).

Some benchmarks on Fortran/ruby speed differences are in `bench.rb`.

## Compiling

See `makefile` for compilation commands, assumes presence of gfortran.

When using `bind(c, name = 'foo')` the dylib generated will have symbols that match the
value specified by name. When this isn't possible, e.g. when you're working with a Fortran
derived type that is not `bind(c)`, or you're using a Fortran pointer, the compiled dylib
symbols will be different.

You can inspect them using the commandline tool `nm`, e.g. `nm -g ffi_multarray.dylib`.

## Calling Fortran

Fortran 95 (I believe) introduced constructs for simplifying interop with C, which we can use
to work with ruby. One major difference between C and Fortran we need to take into account
is that C is call-by-value, while Fortran is (basically) call by reference (see [Call by copy-restore](https://en.wikipedia.org/wiki/Evaluation_strategy#Call_by_copy-restore)
for more information).

We can work around this by a mixture of Fortran `value` declarations that force call-by-value
evaluation, `use ISO_C_BINDING`, `integer(c_int)`, and some extra indirection with pointers.

## Return an integer to ruby

We don't need to explicitly make `ret_i` a `c_int` here.

ruby ffi:

```ruby
attach_function :ret_i, [], :int
puts Flib.ret_i
```

ruby fiddle

```ruby
ret_i = Fiddle::Function.new(
  fortlib['ret_i'],
  [],
  Fiddle::TYPE_INT
)
puts ret_i.call
```

fortran:

```fortran
integer function ret_i() bind(c, name = 'ret_i')
  ret_i = 3
end function ret_i
```

## Allocate and return a Fortran array from a subroutine

Here we allocate the array in ruby, pass a pointer to Fortran, and Fortran populates the array values.

ruby ffi:

```ruby
attach_function :assign_arr, [ :pointer ], :void
...
ptr = FFI::MemoryPointer.new(:int, 5)
Flib.assign_arr(ptr)
int_ptr = ptr.read_pointer
puts "ints: #{int_ptr.read_array_of_int(5)}"
=> [1, 2, 3, 4, 5]
```

ruby fiddle:

```ruby
assign_arr = Fiddle::Function.new(
  fortlib['assign_arr'],
  [Fiddle::TYPE_VOIDP],
  Fiddle::TYPE_VOID
)
assign_arr_ptr = Fiddle::Pointer.malloc(5 * Fiddle::SIZEOF_INT)
assign_arr.call(assign_arr_ptr.ref)
assigned = (0..4).map { |i| assign_arr_ptr[i*Fiddle::SIZEOF_INT] }
puts "assigned: #{assigned}"
```

fortran:

```fortran
subroutine assign_arr (my_arr) bind(c, name = 'assign_arr')
  implicit none
  integer, target, allocatable, dimension(:) :: my_arr
  allocate(my_arr(0:4))
  my_arr = [1,2,3,4,5]
end subroutine assign_arr
```

## Pass an array of int to Fortran function, get the result of an operation on those ints

For some reason, this won't work with a deferred shape array, you must pass the size of the array,
F77-style, otherwise Fortran thinks the array has zero length -- it won't segfault (in my
experience), it will just behave incorrectly.

Create a pointer with enough space, write the values to the pointer, then pass it along with
its size to Fortran.

ruby ffi:

```ruby
attach_function :__exports_MOD_sum_arr, [ :pointer, :int ], :int
...
arr_ptr = FFI::MemoryPointer.new(:int, 10)
arr_ptr.write_array_of_int((1..10).to_a)
sum = Flib.__exports_MOD_sum_arr(arr_ptr, 10)
puts "sum: #{sum}"
```

ruby fiddle:

```ruby
sum_arr = Fiddle::Function.new(
  fortlib['__exports_MOD_sum_arr'],
  [Fiddle::TYPE_INTPTR_T, Fiddle::TYPE_INT],
  Fiddle::TYPE_INT
)
ptr = Fiddle::Pointer.malloc(10 * Fiddle::SIZEOF_INT)
(1..10).to_a.each {|i| ptr[i*Fiddle::SIZEOF_INT] = i+1}
sum = sum_arr.call(ptr, 10)
puts "sum: #{sum}"
```

fortran: 

```fortran
integer function sum_arr(arr, n)
  integer, intent(in), value :: n
  integer, dimension(n), intent(in) :: arr
  sum_arr = sum(arr)
end function sum_arr
```

For large arrays, Fortran may be faster than Ruby, though for small arrays, the cost of
interacting with the pointer may offset any performance boosts.

E.g., for summing an array, Fortran may be about an order of magnitude faster.

```
Rehearsal -------------------------------------------
fortran   0.000000   0.010000   0.010000 (  0.008619)
ruby      0.060000   0.000000   0.060000 (  0.054099)
---------------------------------- total: 0.070000sec

              user     system      total        real
fortran   0.000000   0.000000   0.000000 (  0.006263)
ruby      0.050000   0.000000   0.050000 (  0.055970)
```

For computing dot product of two arrays, Fortran may be ~2x faster.

```
Rehearsal -------------------------------------------
fortran   0.000000   0.000000   0.000000 (  0.000016)
ruby      0.000000   0.000000   0.000000 (  0.000036)
---------------------------------- total: 0.000000sec

              user     system      total        real
fortran   0.000000   0.000000   0.000000 (  0.000013)
ruby      0.000000   0.000000   0.000000 (  0.000035)
```


## Set values on a Fortran derived type, and return a pointer to it

Here we can't use `bind(c)` because we're returning a Fortran pointer, so using `nm` we 
determine the subroutine name in the dylib is `__exports_MOD_sub_p`, based on the Fortran
module name.

The Fortran derived type point variable, here called `gpoint`, must be declared as module
data. Every effort I made to avoid this resulted in segfaults when interoping with ruby,
I'm assuming because the `point` object would get freed when it went out of scope in the
subroutine.

In order to interact with the integers passed to the Fortran subroutine, they must be both
declared as `c_int` and passed by value.

The fiddle code here took a long to time figure out. You might think you'd be able to do something
like call `to_value` on the pointer you passed to Fortran; unfortunately, the Fortran code
overwrites the first two ints of our ruby object, which translates to the same address space as that
which is allocated for the ruby objec'ts RBasic C struct, the first 8 bytes of which is used for 
ruby object flags. There may be some more direct way to accomplish this in Fiddle that I couldn't
figure out, but here (and in general) FFI was a bit easier to work with.

ruby ffi:

```ruby
class Point < FFI::Struct
  layout :x, :int,
    :y, :int
end
...
attach_function :__exports_MOD_sub_p, [:int, :int, :pointer], :void
...
point_ptr = FFI::MemoryPointer.new(Point, 1)
Flib.__exports_MOD_sub_p(1,2, point_ptr)
p = Point.new(point_ptr.read_pointer)
puts point_ptr
=> #<FFI::MemoryPointer address=0x00000102d7e450 size=8>
puts "p: #{p}, #{p[:x]}, #{p[:y]}"
=> p: 1, 2
```

ruby fiddle:

```ruby
require 'fiddle/struct'
require 'fiddle/cparser'
include Fiddle::CParser
types, members = parse_struct_signature(['int x','int y']) # from Fiddle::CParser
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
# Fiddle::SIZEOF_UINTPTR_T is 64 bits, size of ptr on i86 platform, unpack it appropriately. 
# You might be able to get away with just using 'L_' here, which should be a platform-appropraite
# size long, and (therefore?) the size of a pointer.
unpack_directive = Fiddle::SIZEOF_UINTPTR_T == 8 ? 'Q' : 'L'
sub_p.call(2, 16, point_ptr)
new_pointer = point_ptr[0, Fiddle::SIZEOF_UINTPTR_T].unpack(unpack_directive).first
point = Point.new(new_pointer)
puts point.x
# => 2
puts point.y
# => 16
```

fortran:

```fortran
type point
  integer :: x, y
end type point

type (point), target :: gpoint

subroutine sub_p(a, b, p)
  implicit none
  integer(c_int), intent(in), value :: a, b
  type (point), intent(inout), pointer :: p
  gpoint%x = a
  gpoint%y = b
  p => gpoint
end subroutine sub_p
```

## Allocate an array of Fortran derived types, return a pointer to it

This is sort of a workaround for the limitation in the previous example: here, we don't have
to declare the variable in the module data section, we can rely on the fact that the Fortran
intrinsic `allocate` will set aside space for the array of `point`s, so that they aren't 
automatically freed. At least, this is my theory for why this works.

This example builds on the previous one. We initialize a new array of `point`s in the 
subroutine, allocate memory for it, assign some values to the `point`s, then return
a pointer to the array.

In ruby, we can effectively iterate through the array by incrementing the memory location from
which we are reading by the size of our FFI `Point` class.

Caveats:
* Printing the array points will occasionally yield junk data, e.g.:
  ```
  p2: 270510300, -1879048192
  p3: 272107354, -1879048192
  ```
* This will occasionally segfault.

ruby ffi:

```ruby
attach_function :__exports_MOD_sub_p_arr, [:int, :int, :pointer], :void
...
point_ptr_arr = FFI::MemoryPointer.new(Point, 2, true)
Flib.__exports_MOD_sub_p_arr(4, 7, point_ptr_arr)
p2 = Point.new(point_ptr_arr.read_pointer)
puts "p2: #{p2}, #{p2[:x]}, #{p2[:y]}"
=> p2: 4, 7
p3 = Point.new(point_ptr_arr.read_pointer + Point.size)
puts "p3: #{p3}, #{p3[:x]}, #{p3[:y]}"
=> p3: 8, 14
```

ruby fidde:

```ruby
# not yet implemented
```

fortran:

```fortran
type point
  integer :: x, y
end type point
...
subroutine sub_p_arr(a, b, p)
  implicit none
  integer(c_int), intent(in), value :: a, b
  type (point), target, allocatable, dimension(:) :: point_arr
  type (point), pointer, dimension(:) :: p
  allocate(point_arr(1:2))
  point_arr(1)%x = a
  point_arr(1)%y = b
  point_arr(2)%x = a + a
  point_arr(2)%y = b + b
  p => point_arr
end subroutine sub_p_arr
```
