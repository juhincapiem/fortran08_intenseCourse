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
        real(dp), intent(in)    :: x(n)
        real(dp), intent(inout) :: y(n)
        integer(dp_int) :: i

        !$omp target teams distribute parallel do
        do i = 1, n
            y(i) = x(i) + y(i)
        end do
        !$omp end target teams distribute parallel do

    end subroutine add

end module utils


program gpu_inline
    use utils
    use omp_lib
    use iso_fortran_env, only: int64
    implicit none

    integer(dp_int), parameter :: N = ishft(1_int64, 20)

    real(dp), allocatable :: x(:), y(:)
    integer(dp_int) :: i
    integer :: ierr, rep
    real(dp) :: maxError, t0, t1, t_inline, t_sub

    allocate(x(N), y(N), stat=ierr)
    if (ierr /= 0) then
        print *, "Allocation failed"
        stop 1
    end if

    do i = 1, N
        x(i) = 1.0_dp
        y(i) = 2.0_dp
    end do

    !$omp target data map(to: x) map(tofrom: y)

    ! calentar: paga el JIT
    !$omp target
    !$omp end target

    ! ---------- A: kernel escrito aqui mismo ----------
    t_inline = huge(1.0_dp)
    do rep = 1, 10

        !$omp target teams distribute parallel do
        do i = 1, N
            y(i) = 2.0_dp
        end do
        !$omp end target teams distribute parallel do

        t0 = omp_get_wtime()

        !$omp target teams distribute parallel do
        do i = 1, N
            y(i) = x(i) + y(i)
        end do
        !$omp end target teams distribute parallel do

        t1 = omp_get_wtime()

        if (rep > 1) t_inline = min(t_inline, t1 - t0)
    end do

    ! ---------- B: el mismo kernel dentro de add ----------
    t_sub = huge(1.0_dp)
    do rep = 1, 10

        !$omp target teams distribute parallel do
        do i = 1, N
            y(i) = 2.0_dp
        end do
        !$omp end target teams distribute parallel do

        t0 = omp_get_wtime()
        call add(N, x, y)
        t1 = omp_get_wtime()

        if (rep > 1) t_sub = min(t_sub, t1 - t0)
    end do

    !$omp end target data

    maxError = maxval(abs(y - 3.0_dp))

    print '(A, F10.6, A)', "A) kernel inline:     ", t_inline, " s"
    print '(A, F10.6, A)', "B) kernel en add:     ", t_sub, " s"
    print '(A, ES12.5)',   "max error:            ", maxError

    deallocate(x, y)

end program gpu_inline