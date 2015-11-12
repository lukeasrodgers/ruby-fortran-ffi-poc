module exports
  use ISO_C_BINDING
  implicit none

  integer, dimension(:), allocatable, target :: xs
  integer :: foo = 1

  type point
    integer :: x, y
  end type point

  contains

    ! this will not update, due to use of `value`
    subroutine wont_set_out (input, output) bind(c, name = 'wont_set_out')
      implicit none
      integer, intent(in), value :: input
      integer, value :: output
      output = 3
    end subroutine wont_set_out

    subroutine assign_arr (my_arr) bind(c, name = 'assign_arr')
      implicit none
      integer, target, allocatable, dimension(:) :: my_arr
      allocate(my_arr(0:4))
      my_arr = [1,2,3,4,5]
    end subroutine assign_arr

    ! works
    integer function ret_i() bind(c, name = 'ret_i')
      ret_i = 3
    end function ret_i

    ! this compiles, but doesn't interop with ruby
    integer function ret_loc_i(n) bind(c, name = 'ret_loc_i')
      ! fails unless we specify call by value
      ! integer, intent(in), value :: n
      integer, intent(in), value :: n
      integer i
      i = n + 4
      ! allocate(xs(n))
      ! xs = ([(i,i=1,n)])
      ! ret_loc_i = loc(xs)
      ret_loc_i = loc(foo)
    end function ret_loc_i

    ! compiles but doesn't work with ruby...
    ! type (point) function ret_p(a, b) bind(c, name = 'ret_p') 
      ! implicit none
      ! integer, intent(in) :: a, b
      ! type (point) :: p
      ! ret_p%x = a
      ! ret_p%y = b
      ! ret_p = p
    ! end function ret_p

    function ret_p(a, b) result(p)
      implicit none
      integer, intent(in) :: a, b
      type (point), target :: p
      p%x = a
      p%y = b
    end function ret_p

    ! tried changing inout to value, doesn't work with ruby still
    ! tried using bind_c, doesn't work
    ! 
    subroutine sub_p(a, b, p)
      implicit none
      integer, intent(in) :: a, b
      type (point), intent(inout) :: p
      p%x = a
      p%y = b
    end subroutine sub_p

    ! this won't work, return type of BIND(C) function can't be an array
    ! function fn_arr(n) bind(c, name = 'fn_arr')
      ! integer, intent(in) :: n
      ! integer, dimension(n) :: fn_arr
      ! integer i
      ! fn_arr = ([(i, i=1, n)])
    ! end function fn_arr

    ! this also won't work, can't have bind(c) and return pointer
    ! function point_to_xs(n) bind(c, name = 'point_to_xs')
      ! implicit none
      ! integer, intent(in) :: n
      ! integer, dimension(:), pointer :: point_to_xs
      ! integer i

      ! allocate(xs(n))
      ! xs = ([(i,i=1,n)])
      ! point_to_xs => xs
    ! end function point_to_xs


    ! function return_arr_ptr(arr_ptr) bind(c, name = 'return_arr_ptr') result(retptr)
      ! implicit none
      ! integer, dimension(:), pointer :: retptr
      ! integer, dimension(5), pointer :: arr_ptr

      ! allocate(myarr(0:4))
      ! myarr = [1,2,3,4,5]
      ! retptr => myarr
    ! end function return_arr_ptr
end module exports
