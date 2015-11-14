This experimental code is an attempted proof-of-concept for ruby calling Fortran code
via the [ruby ffi](https://github.com/ffi/ffi) library.

It works on OSX and gfortran 5.1.0 -- I have no idea if it will work with other setups.

My familiarity with both ruby-ffi and Fortran is very limited, so there are probably many
mistakes and errors of understanding here.

My goal was to figure out how to use Fortran subroutines and/or functions to be callable from
ruby, and manipulate and return data. After a lot of experimentation and segfaults, here 
are a few approaches I was able to get *mostly* working.

The following code snippets leave off the ruby-ffi/Fortran boilerplate, which you can get
from the src in this repo. It assumes a ruby module named Flib.

## Compiling

See `makefile` for compilation commands, assumes presence of gfortran.

When using `bind(c, name = 'foo')` the dylib generated will have symbols that match the
value specified by name. When this isn't possible, e.g. when you're working with a Fortran
derived type that is not `bind(c)`, or you're using a Fortran pointer, the compiled dylib
symbols will be different.

You can inspect them using the commandline tool `nm`, e.g. `nm -g ffi_multarray.dylib`.

## Calling Fortran

Fortran 95 (I believe) introduced constructs for simplifying interop with C, which we can use
to work with ruby-ffi. One major difference between C and Fortran we need to take into account
is that C is call-by-value, while Fortran is (basically) call by reference (see [Call by copy-restore](https://en.wikipedia.org/wiki/Evaluation_strategy#Call_by_copy-restore)
for more information).

We can work around this by a mixture of Fortran `value` declarations that force call-by-value
evaluation, `use ISO_C_BINDING`, `integer(c_int)`, and some extra indirection with pointers.

## Return an integer to ruby

We don't need to explicitly make `ret_i` a `c_int` here.

ruby:

```ruby
attach_function :ret_i, [], :int
```

fortran:

```fortran
integer function ret_i() bind(c, name = 'ret_i')
  ret_i = 3
end function ret_i
```

## Allocate and return a Fortran array from a subroutine

ruby:

```ruby
attach_function :assign_arr, [ :pointer ], :void
...
ptr = FFI::MemoryPointer.new(:int, 5)
Flib.assign_arr(ptr)
int_ptr = ptr.read_pointer
puts "ints: #{int_ptr.read_array_of_int(5)}"
=> [1, 2, 3, 4, 5]
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

ruby:

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
=> p: #<Point:0x00000101df3ea8>, 1, 2
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

ruby:

```ruby
attach_function :__exports_MOD_sub_p_arr, [:int, :int, :pointer], :void
...
point_ptr_arr = FFI::MemoryPointer.new(Point, 2, true)
Flib.__exports_MOD_sub_p_arr(4, 7, point_ptr_arr)
p2 = Point.new(point_ptr_arr.read_pointer)
puts "p2: #{p2}, #{p2[:x]}, #{p2[:y]}"
=> p2: #<Point:0x00000101df3c28>, 4, 7
p3 = Point.new(point_ptr_arr.read_pointer + Point.size)
puts "p3: #{p3}, #{p3[:x]}, #{p3[:y]}"
=> p3: #<Point:0x00000101df39f8>, 8, 14
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
