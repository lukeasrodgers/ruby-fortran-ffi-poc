module exports

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

    ! this won't work, return type of BIND(C) function can't be an array
    ! function fn_arr(n) bind(c, name = 'fn_arr')
      ! integer, intent(in) :: n
      ! integer, dimension(n) :: fn_arr
      ! integer i
      ! fn_arr = ([(i, i=1, n)])
    ! end function fn_arr

    ! function return_arr_ptr(arr_ptr) bind(c, name = 'return_arr_ptr') result(retptr)
      ! implicit none
      ! integer, dimension(:), pointer :: retptr
      ! integer, dimension(5), pointer :: arr_ptr

      ! allocate(myarr(0:4))
      ! myarr = [1,2,3,4,5]
      ! retptr => myarr
    ! end function return_arr_ptr
end module exports
