require 'fiddle'
require 'fiddle/struct'
require 'fiddle/cparser'

clib = Fiddle.dlopen('cpoint.dylib')

include Fiddle::CParser
types, members = parse_struct_signature(['int x','int y'])

Point = Fiddle::CStructBuilder.create(Fiddle::CStruct, types, members)

get_cpoint = Fiddle::Function.new(
  clib['get_cpoint'],
  [Fiddle::TYPE_INT, Fiddle::TYPE_INT],
  Fiddle::TYPE_VOIDP
)
point = get_cpoint.call(1,4)
newp = Point.new(point)
puts newp.x
puts newp.y

mutate_cpoint = Fiddle::Function.new(
  clib['mutate_cpoint'],
  [Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP],
  Fiddle::TYPE_VOID
)

pointer = Fiddle::Pointer.malloc(Point.size)
# this works too, except then we have an extra object
# mutatable_cpoint = Point.malloc
# mutatable_cpoint_ptr = Fiddle::Pointer.new(mutatable_cpoint.object_id << 1)
mutate_cpoint.call(1, 16, pointer)
# setting size enables us to call to_str, if we want; to_s is similar, but only converts to string until it gets NULL byte
pointer.size = Point.size

# Here we would have to discard our old mutable_cpoint, as it would have been altered by our C code, and wouldn't be a valid ruby object any more.
mutated_point = Point.new(pointer)
puts mutated_point.x
puts mutated_point.y
