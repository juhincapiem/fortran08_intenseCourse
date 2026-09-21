module utils
    use iso_fortran_env, only: real32, int64
    implicit none

    private
    public :: dp, dp_int, heavy_cpu, heavy_gpu

    integer, parameter :: dp = real32
    integer, parameter :: dp_int = int64

contains

    ! ---- misma cuenta, en la CPU (un solo hilo) ----
    subroutine heavy_cpu(n, nwork, x, y)
        integer(dp_int), intent(in) :: n
        integer, intent(in)         :: nwork
        real(dp), intent(in)        :: x(n)
        real(dp), intent(out)       :: y(n)
        integer(dp_int) :: i
        integer :: k
        real(dp) :: tmp

        do i = 1, n
            tmp = x(i)
            do k = 1, nwork
                tmp = tmp * 0.999_dp + 0.001_dp
            end do
            y(i) = tmp
        end do

    end subroutine heavy_cpu


    ! ---- misma cuenta, en la GPU ----
    subroutine heavy_gpu(n, nwork, x, y)
        integer(dp_int), intent(in) :: n
        integer, intent(in)         :: nwork
        real(dp), intent(in)        :: x(n)
        real(dp), intent(out)       :: y(n)
        integer(dp_int) :: i
        integer :: k
        real(dp) :: tmp

        !$omp target teams distribute parallel do private(tmp, k)
        do i = 1, n
            tmp = x(i)
            do k = 1, nwork
                tmp = tmp * 0.999_dp + 0.001_dp
            end do
            y(i) = tmp
        end do
        !$omp end target teams distribute parallel do

    end subroutine heavy_gpu

end module utils


program intensidad
    use utils
    use omp_lib
    use iso_fortran_env, only: int64
    implicit none

    integer(dp_int), parameter :: N = ishft(1_int64, 20)
    integer, parameter :: NWORK = 200

    real(dp), allocatable :: x(:), y(:)
    integer(dp_int) :: i
    integer :: ierr, rep
    real(dp) :: t0, t1, t_cpu, t_gpu, ref

    allocate(x(N), y(N), stat=ierr)
    if (ierr /= 0) then
        print *, "Allocation failed"
        stop 1
    end if

    do i = 1, N
        x(i) = 1.0_dp
    end do

    ! ---------------- CPU ----------------
    t_cpu = huge(1.0_dp)
    do rep = 1, 5
        t0 = omp_get_wtime()
        call heavy_cpu(N, NWORK, x, y)
        t1 = omp_get_wtime()
        if (rep > 1) t_cpu = min(t_cpu, t1 - t0)
    end do

    ref = y(1)          ! guardamos el resultado de la CPU para comparar

    ! ---------------- GPU ----------------
    !$omp target data map(to: x) map(from: y)

    !$omp target
    !$omp end target                         ! calentamiento: paga el JIT

    t_gpu = huge(1.0_dp)
    do rep = 1, 5
        t0 = omp_get_wtime()
        call heavy_gpu(N, NWORK, x, y)
        t1 = omp_get_wtime()
        if (rep > 1) t_gpu = min(t_gpu, t1 - t0)
    end do

    !$omp end target data

    print '(A, I0, A, I0)',    "N = ", N, ",  operaciones por elemento = ", 2*NWORK
    print '(A, F10.6, A)',     "CPU (1 hilo):  ", t_cpu, " s"
    print '(A, F10.6, A)',     "GPU:           ", t_gpu, " s"
    print '(A, F10.2, A)',     "aceleracion:   ", t_cpu / t_gpu, " x"
    print '(A, ES14.7)',       "CPU y(1) = ", ref
    print '(A, ES14.7)',       "GPU y(1) = ", y(1)

    deallocate(x, y)

end program intensidad