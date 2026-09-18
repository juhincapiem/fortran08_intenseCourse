module utils
    use iso_fortran_env, only: real64, int64
    implicit none

    private
    public :: dp, dp_int, add

    integer, parameter :: dp = real64
    integer, parameter :: dp_int = int64

    contains

    subroutine add(n, x, y)
        integer(dp_int), intent(in) :: n
        real(dp), intent(in) :: x(n)
        real(dp), intent(inout) :: y(n)
        integer(dp_int) :: i

        do i = 1, n, 1
            y(i) = x(i) + y(i)
        end do

    end subroutine add


end module utils




program serial_test
    use utils
    implicit none

    integer(dp_int), parameter :: N = ishft(1,20)

    real(dp) :: x(N)
    real(dp) :: y(N)

    integer :: i
    real(dp) :: maxError = 0.0_dp

    ! Initialize x and y arrays on the host
    do i = 1, n, 1
        x(i) = 1.0_dp
        y(i) = 2.0_dp
    end do

    ! Run kernel on 1M elements on the CPU
    call add(N, x, y)

    ! Check for errors (all values should be 3.0f
    do i = 1, n, 1
        maxError = max(maxError, abs(y(i) - 3.0_dp) )
    end do
    
    print '(A, ES12.5)', "The max error is: ", maxError

end program serial_test