! =============================================================================
!  bench.F90  --  y = x + y  en CPU (OpenMP) y en GPU (OpenMP offload)
!
!  Un solo archivo fuente para todas las variantes:
!    - la precision se elige al compilar:   -DUSE_REAL32  -> real32
!                                           (sin nada)    -> real64
!    - el modo, el tamano y las repeticiones se eligen al ejecutar.
!
!  Uso:
!    ./bench <modo> <exponente> <nrep> <nwarm>
!
!      modo       cpu        : !$omp parallel do, con los hilos que diga el entorno
!                 gpu_kernel : solo el kernel; x e y ya residentes en la GPU
!                 gpu_total  : kernel + copias por PCIe en cada llamada
!      exponente  N = 2**exponente
!      nrep       repeticiones medidas (se imprimen)
!      nwarm      repeticiones de calentamiento (se descartan)
!
!  Salida (stdout): una linea CSV por repeticion medida:
!    precision,mode,threads,N,rep,time_s,max_err
!  Mensajes informativos y errores van a stderr, asi no ensucian el CSV.
! =============================================================================


module kinds
    use iso_fortran_env, only: real32, real64, int64
    implicit none
    
    private

    public :: wp, ip, prec_bits

#ifdef USE_REAL32
    integer, parameter :: wp = real32
    integer, parameter :: prec_bits = 32
#else
    integer, parameter :: wp = real64
    integer, parameter :: prec_bits = 64
#endif

    integer, parameter :: ip = int64

end module kinds


module kernels
    use kinds
    implicit none
    private
    public :: add_cpu, add_gpu, reset_gpu


    contains

    ! Mismo calculo que el tutorial de NVIDIA, repartido entre hilos de CPU
    subroutine add_cpu(n, x, y)
        integer(ip), intent(in)    :: n
        real(wp),    intent(in)    :: x(n)
        real(wp),    intent(inout) :: y(n)
        integer(ip) :: i
 
        !$omp parallel do
        do i = 1, n
            y(i) = x(i) + y(i)
        end do
        !$omp end parallel do
 
    end subroutine add_cpu


    ! El mismo calculo en la GPU.
    subroutine add_gpu(n, x, y)
        integer(ip), intent(in)    :: n
        real(wp),    intent(in)    :: x(n)
        real(wp),    intent(inout) :: y(n)
        integer(ip) :: i
 
        !$omp target teams distribute parallel do
        do i = 1, n
            y(i) = x(i) + y(i)
        end do
        !$omp end target teams distribute parallel do
 
    end subroutine add_gpu


    subroutine reset_gpu(n, y)
        integer(ip), intent(in)  :: n
        real(wp),    intent(out) :: y(n)
        integer(ip) :: i

        !$omp target teams distribute parallel do
        do i = 1, n
            y(i) = 2.0_wp
        end do
        !$omp end target teams distribute parallel do
    end subroutine reset_gpu

end module kernels


program bench
    use iso_fortran_env, only : real64, error_unit
    use omp_lib
    use kinds
    use kernels
    implicit none

    character(len=32) :: mode, arg
    integer      :: expo, nrep, nwarm, rep, ierr, nthreads
    integer(ip)  :: n, i
    real(wp), allocatable :: x(:), y(:)
    real(real64) :: t0, t1, err          ! los cronometros SIEMPRE en real64   
    
    if (command_argument_count() /= 4) then
        write(error_unit, '(A)') "uso: bench <cpu|gpu_kernel|gpu_total> <exponente> <nrep> <nwarm>"
        stop 1
    end if

    call get_command_argument(1,mode)
    call get_command_argument(2, arg)
    read(arg, *, iostat=ierr) expo
    if (ierr /= 0 .or. expo < 1 .or. expo > 30) call fail("exponente invalido (1..30)")

    call get_command_argument(3, arg)
    read(arg, *, iostat=ierr) nrep
    if (ierr /= 0 .or. nrep < 1) call fail("nrep invalido")

    call get_command_argument(4, arg);  read(arg, *, iostat=ierr) nwarm
    if (ierr /= 0 .or. nwarm < 0) call fail("nwarm invalido")


    n = ishft(1_ip, expo)

    ! ---------------- memoria (heap) ----------------
    allocate(x(n), y(n), stat = ierr)
    if (ierr /= 0) call fail("allocate falló")

    !$omp parallel do
    do i = 1, n
        x(i) = 1.0_wp
        y(i) = 2.0_wp
    end do
    !$omp end parallel do

    
    ! ---------------- medicion ----------------
    select case (trim(mode))
 
    ! ---- CPU: los hilos los decide el entorno (OMP_NUM_THREADS, OMP_PLACES) ----
    case ("cpu")
        nthreads = omp_get_max_threads()
        call info()
 
        do rep = 1, nwarm + nrep
            call reset_host()
            t0 = omp_get_wtime()
            call add_cpu(n, x, y)
            t1 = omp_get_wtime()
            err = max_error_host()
            if (rep > nwarm) call emit(rep - nwarm, t1 - t0, err)
        end do

    ! ---- GPU, solo kernel: los datos suben UNA vez y se quedan en la GPU ----
    case ("gpu_kernel")
        nthreads = 0
        call info()
        call check_gpu()                   ! de paso paga el JIT / arranque
 
        ! map(alloc: y): reserva y en la GPU sin copiar nada; la llenamos alli
        !$omp target data map(to: x) map(alloc: y)
        do rep = 1, nwarm + nrep
 
            ! reset EN LA GPU (la copia del host no la ve nadie aqui dentro)
        call reset_gpu(n, y)
 
            t0 = omp_get_wtime()
            call add_gpu(n, x, y)
            t1 = omp_get_wtime()
 
            ! traer y al host SOLO para verificar; queda fuera del cronometro
            !$omp target update from(y)
            err = max_error_host()
            if (rep > nwarm) call emit(rep - nwarm, t1 - t0, err)
        end do
        !$omp end target data
 
    ! ---- GPU, total: cada llamada sube x e y y baja y (lo que cuesta de verdad) ----
    case ("gpu_total")
        nthreads = 0
        call info()
        call check_gpu()
 
        do rep = 1, nwarm + nrep
            call reset_host()
            t0 = omp_get_wtime()
            !$omp target data map(to: x) map(tofrom: y)
            call add_gpu(n, x, y)
            !$omp end target data
            t1 = omp_get_wtime()
            err = max_error_host()
            if (rep > nwarm) call emit(rep - nwarm, t1 - t0, err)
        end do
 
    case default
        call fail("modo desconocido: " // trim(mode))
    end select
 
    deallocate(x, y)

    contains

    subroutine reset_host()
        integer(ip) :: j
        !$omp parallel do
        do j = 1, n
            y(j) = 2.0_wp
        end do
        !$omp end parallel do
    end subroutine reset_host
 
 
    ! Bucle explicito: maxval(abs(y - 3)) podria crear un array temporal de
    ! tamano N, y un temporal grande es justo lo que revienta la pila.
    function max_error_host() result(e)
        real(real64) :: e
        integer(ip)  :: j
        e = 0.0_real64
        do j = 1, n
            e = max(e, real(abs(y(j) - 3.0_wp), real64))
        end do
    end function max_error_host
 
 
    ! Comprueba que la GPU existe y que el codigo corre ALLI (no en la CPU).
    subroutine check_gpu()
        logical :: on_host
        if (omp_get_num_devices() < 1) call fail("OpenMP no ve ninguna GPU")
        on_host = .true.
        !$omp target map(from: on_host)
        on_host = omp_is_initial_device()
        !$omp end target
        if (on_host) call fail("la region target corrio en la CPU: no hay offload")
    end subroutine check_gpu
 
 
    subroutine info()
        write(error_unit, '(A,I0,A,A,A,I0,A,I0,A,I0)') &
            "# prec=", prec_bits, "  mode=", trim(mode), "  N=2^", expo, &
            "  host_threads=", omp_get_max_threads(), "  gpus=", omp_get_num_devices()
    end subroutine info
 
 
    ! Escribe una fila CSV sin espacios sobrantes.
    subroutine emit(r, t, e)
        integer,      intent(in) :: r
        real(real64), intent(in) :: t, e
        character(len=32) :: st, se
        write(st, '(ES15.8)') t
        write(se, '(ES11.4)') e
        write(*, '(I0,",",A,",",I0,",",I0,",",I0,",",A,",",A)') &
            prec_bits, trim(mode), nthreads, n, r, trim(adjustl(st)), trim(adjustl(se))
    end subroutine emit
 
 
    subroutine fail(msg)
        character(len=*), intent(in) :: msg
        write(error_unit, '(A)') "ERROR: " // msg
        stop 2
    end subroutine fail

end program bench

