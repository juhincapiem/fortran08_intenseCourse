module utils
    use iso_fortran_env, only: real64, int64, real32
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


program gpu_data
    use utils
    use omp_lib
    use iso_fortran_env, only: int64
    implicit none

    integer(dp_int), parameter :: N = ishft(1_int64, 20)

    real(dp), allocatable :: x(:), y(:)
    integer(dp_int) :: i
    integer :: ierr, rep
    real(dp) :: maxError, t0, t1, t_best, t_total

    allocate(x(N), y(N), stat=ierr)
    if (ierr /= 0) then
        print *, "Allocation failed"
        stop 1
    end if

    ! WARMING-UP
    !$omp target
    !$omp end target

    t_total = omp_get_wtime()

    !$omp target data map(alloc: x) map(alloc: y)

    !$omp target teams distribute parallel do
    do i = 1, N
        x(i) = 1.0_dp
        !y(i) = 2.0_dp
    end do
    !$omp end target teams distribute parallel do


    t_best = huge(1.0_dp)
    do rep = 1, 10

        !$omp target teams distribute parallel do
        do i = 1, N
            !x(i) = 1.0_dp
            y(i) = 2.0_dp
        end do
        !$omp end target teams distribute parallel do


        t0 = omp_get_wtime()
        call add(N, x, y)
        t1 = omp_get_wtime()

        if (rep > 1) t_best = min(t_best, t1 - t0)
    end do

    !$omp target update from(y)
    !$omp end target data

    t_total = omp_get_wtime() - t_total

    maxError = maxval(abs(y - 3.0_dp))

    print '(A, F10.6, A)', "kernel only:   ", t_best, " s"
    print '(A, F10.6, A)', "whole region:  ", t_total, " s"
    print '(A, ES12.5)',   "max error:     ", maxError

    deallocate(x, y)

end program gpu_data
! gfortran-13 -fopenmp -foffload=nvptx-none -O2 -Wall ./add_gpu_parallel.f90 -o ./add_gpu_parallel.x && OMP_TARGET_OFFLOAD=MANDATORY ./add_gpu_parallel.x
! nvfortran -mp=gpu -gpu=cc80 -O2 -Minfo=mp ./add_gpu_parallel.f90 -o ./add_gpu_parallel.x && OMP_TARGET_OFFLOAD=MANDATORY ./add_gpu_parallel.x
! nvfortran -mp=gpu -gpu=cc75 -O2 -Minfo=mp ./add_gpu_parallel.f90 -o ./add_gpu_parallel.x && OMP_TARGET_OFFLOAD=MANDATORY ./add_gpu_parallel.x