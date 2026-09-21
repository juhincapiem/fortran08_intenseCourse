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

        !$omp parallel do
        do i = 1, n, 1
            y(i) = x(i) + y(i)
        end do
        !$omp end parallel do 

    end subroutine add


end module utils

program parallel_test
      use utils
    use omp_lib
    implicit none

    integer(dp_int), parameter :: N = ishft(1,20)

    real(dp), allocatable :: x(:), y(:)

    integer(dp_int) :: i
    integer :: ierr, rep
    real(dp) :: maxError = 0.0_dp
    real(dp) :: t0, t1, t_best


    allocate(x(N), y(N), stat = ierr)
    if (ierr /= 0 ) then
        print *, "Allocation failed"
        stop 1
    end if

    ! Initialize x and y arrays on the host
    do i = 1, n, 1
        x(i) = 1.0_dp
        y(i) = 2.0_dp
    end do

    ! ---- first call: includes device init and PTX JIT ----
    t_best = huge(1.0_dp)
    do rep = 1, 10
    
        t0 = omp_get_wtime()
        call add(N, x, y)
        t1 = omp_get_wtime()

        if (rep > 1) t_best = min(t_best, t1 - t0)

        do i = 1, n, 1
            y(i) = 2.0_dp
        end do 
    end do

    print '(A, F10.6, A)', "Best  call: ", t_best, " s"

    ! reset y so the second call has the same starting point
    do i = 1, N
        y(i) = 2.0_dp
    end do

    ! ---- second call: device already warm ----
    t0 = omp_get_wtime()
    call add(N, x, y)
    t1 = omp_get_wtime()
    print '(A, F10.6, A)', "One more call: ", t1 - t0, " s"
    

    ! Check for errors (all values should be 3.0f
    do i = 1, n, 1
        maxError = max(maxError, abs(y(i) - 3.0_dp) )
    end do
    
    print '(A, ES12.5)', "The max error is: ", maxError

    deallocate(x, y)


end program parallel_test

! gfortran -fopenmp -Wall -O2 ./add_cpu_parallel.f90 -o ./add_cpu_parallel.x && ./add_cpu_parallel.x 