subroutine temgpu_solite(a)
    ! ------------------------------------------------------------------
    ! GPU version (OpenMP target offload, no CrayPat regions).
    !
    ! Matrix-free Conjugate Gradient solve of the steady temperature problem
    !     -div( grad(T) ) = f ,   f = 1 (constant source)
    ! with homogeneous Dirichlet boundary conditions (T = 0 on kfl_fixno == 1).
    !
    ! Data strategy: the mesh goes up once, all CG vectors live on the
    ! device for the whole solve, the solution u comes down once. Inside
    ! the CG loop only the dot-product scalars cross host <-> device.
    !
    ! Timing: MPI_Wtime around each phase. All kernels are synchronous
    ! (no nowait), so host-side timers measure the full GPU work.
    ! ------------------------------------------------------------------
    use Mod_TemperatureGPU
    use typre
    implicit none

    class(TemperatureProblemGPU), target :: a

    ! .true.  -> print the residual every iteration (validation runs)
    ! .false. -> only the final summary (timing runs: per-iteration I/O
    !            would add to the measured CG time)
    logical, parameter :: print_residuals = .false.

    integer(ip) :: nelem, ndime, npoinLocal, n, i
    integer(ip), pointer :: lnods(:), pnods(:), ltype(:), nnode(:), ngaus(:)
    integer(ip), pointer :: fixno(:)
    real(rp),    pointer :: coord(:,:), deriv(:,:,:,:), weigp(:,:), shapf(:,:,:)

    real(rp), allocatable :: u(:), b(:), r(:), p(:), Ap(:)

    integer(ip) :: k, maxit, ierr, niter
    integer     :: rank
    real(rp)    :: alpha, beta, denom, rdot, rdot_new, tol, sqrt_rdot_new

    ! Timers (seconds)
    real(8) :: t0, tA, t1, t2, t3, t4, t5, ta
    real(8) :: t_init, t_rhs, t_cgsetup, t_cg, t_apply, t_exit, t_total

    rank = my_rank()
    t0   = wtime()

    if (rank == 0) write(*,*) "temgpu_solite: GPU version (OpenMP offload)"
    a%itera = a%itera + 1 ! usually done in php_solite

    ! ------------------------------------------------------------------
    ! Mesh data from the framework
    ! ------------------------------------------------------------------
    nelem      = a%Mesh%nelem
    ndime      = a%Mesh%ndime
    npoinLocal = a%Mesh%npoinLocal

    lnods => a%Mesh%lnods
    pnods => a%Mesh%pnods
    ltype => a%Mesh%ltype
    coord => a%Mesh%coord
    deriv => a%Mesh%deriv
    weigp => a%Mesh%weigp
    ngaus => a%Mesh%ngaus
    nnode => a%Mesh%nnode
    shapf => a%Mesh%shape

    fixno => a%kfl_fixno(1,:)   ! contiguous here: 1 dof per node
    
    write(*,'(a,i10,a,i10)') " MESH nelem=", nelem, " npoin=", npoinLocal


    ! ------------------------------------------------------------------
    ! CG working arrays and parameters
    ! ------------------------------------------------------------------
    n     = npoinLocal
    maxit = 1000
    tol   = 1.0e-8_rp
    ierr  = 0

    allocate(u(n), b(n), r(n), p(n), Ap(n))

    ! ------------------------------------------------------------------
    ! Device data region for the whole solve:
    !   mesh            -> up once (read-only)
    !   b, r, p, Ap     -> device only (never copied)
    !   u               -> device, copied down once at the end
    ! ------------------------------------------------------------------
    tA = wtime()

    !$omp target data map(to: lnods, coord, deriv, weigp, ltype, pnods, ngaus, fixno, shapf) &
    !$omp             map(alloc: b, r, p, Ap)                                                &
    !$omp             map(from: u)

    ! Initial guess u = 0. This is also the first kernel of the run, so
    ! it pays the one-time GPU code loading: it is counted in t_init.
    !$omp target teams distribute parallel do
    do i = 1, n
        u(i) = 0.0_rp
    end do
    !$omp end target teams distribute parallel do

    t1 = wtime()
    t_init = t1 - tA     ! region entry (mesh upload, device init) + first kernel

    ! ------------------------------------------------------------------
    ! Right-hand side
    ! ------------------------------------------------------------------
    call compute_B(b)
    t2 = wtime()
    t_rhs = t2 - t1

    ! ------------------------------------------------------------------
    ! CG setup: r = b - A*u, p = r, rdot = r.r
    ! ------------------------------------------------------------------
    call Apply_A(u, Ap)

    !$omp target teams distribute parallel do
    do i = 1, n
        r(i) = b(i) - Ap(i)
    end do
    !$omp end target teams distribute parallel do

    !$omp target teams distribute parallel do
    do i = 1, n
        p(i) = r(i)
    end do
    !$omp end target teams distribute parallel do

    call gpu_dot(r, r, n, rdot)
    if (rdot < 0.0_rp) rdot = 0.0_rp

    t3 = wtime()
    t_cgsetup = t3 - t2

    ! ------------------------------------------------------------------
    ! CG loop
    ! ------------------------------------------------------------------
    ierr          = 1   ! assume non-convergence until we break out below
    niter         = 0
    t_apply       = 0.0d0
    sqrt_rdot_new = sqrt(rdot)

    do k = 1, maxit
        niter = k

        ta = wtime()
        call Apply_A(p, Ap)
        t_apply = t_apply + (wtime() - ta)

        call gpu_dot(p, Ap, n, denom)
        if (abs(denom) < 1.0e-30_rp) then
            ierr = 2
            exit
        endif
        alpha = rdot / denom

        ! u = u + alpha*p
        !$omp target teams distribute parallel do
        do i = 1, n
            u(i) = u(i) + alpha * p(i)
        end do
        !$omp end target teams distribute parallel do

        ! r = r - alpha*Ap
        !$omp target teams distribute parallel do
        do i = 1, n
            r(i) = r(i) - alpha * Ap(i)
        end do
        !$omp end target teams distribute parallel do

        call gpu_dot(r, r, n, rdot_new)

        sqrt_rdot_new = sqrt(rdot_new)
        if (print_residuals .and. rank == 0) then
            write(*,*) "CG iteration ", k, " residual norm = ", sqrt_rdot_new
        endif
        if (sqrt_rdot_new < tol) then
            ierr = 0
            exit
        endif

        beta = rdot_new / rdot

        ! p = r + beta*p
        !$omp target teams distribute parallel do
        do i = 1, n
            p(i) = r(i) + beta * p(i)
        end do
        !$omp end target teams distribute parallel do

        rdot = rdot_new
    end do

    t4 = wtime()
    t_cg = t4 - t3

    !$omp end target data

    t5 = wtime()
    t_exit = t5 - t4     ! region exit: copy u back, free device memory

    a%unkno(1,1:npoinLocal) = u
    t_total = wtime() - t0

    ! ------------------------------------------------------------------
    ! Summary (same fields as the CPU version)
    ! ------------------------------------------------------------------
    if (rank == 0) then
        write(*,*) "CG finished with ierr = ", ierr, " after ", niter, &
                   " iterations. Final residual = ", sqrt_rdot_new
        write(*,'(a,i6,8(a,es12.5))') " TIMING version=GPU iters=", niter, &
            " t_total=",           t_total,                    &
            " t_init=",            t_init,                     &
            " t_rhs=",             t_rhs,                      &
            " t_cgsetup=",         t_cgsetup,                  &
            " t_cg=",              t_cg,                       &
            " t_cg_per_iter=",     t_cg    / max(niter, 1_ip), &
            " t_applyA_per_call=", t_apply / max(niter, 1_ip), &
            " t_exit=",            t_exit
    endif

    deallocate(u, b, r, p, Ap)

contains

    subroutine compute_B(b)
        ! b_i = integral N_i * f dV, f = 1, then zeroed at Dirichlet nodes.
        ! All arrays are already present on the device.
        implicit none

        real(rp), intent(out) :: b(:)

        integer(ip) :: ielem, inode, igaus, ielty, ispos, ipoin_i, pnode
        integer(ip) :: idime, jdime
        real(rp)    :: J(3,3), detJ, dvol
        real(rp), parameter :: source = 1.0_rp

        !$omp target teams distribute parallel do
        do ipoin_i = 1, size(b)
            b(ipoin_i) = 0.0_rp
        end do
        !$omp end target teams distribute parallel do

        !$omp target teams distribute parallel do                 &
        !$omp   private(J, detJ, dvol, ielty, ispos, pnode,       &
        !$omp           ipoin_i, inode, igaus, idime, jdime)
        do ielem = 1, nelem

            pnode = pnods(1) ! all elements are the same type here
            ielty = ltype(pnode)
            ispos = (ielem-1) * pnode

            do igaus = 1, ngaus(ielty)

                J = 0.0_rp
                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)
                    do idime = 1, ndime
                        do jdime = 1, ndime
                            J(idime,jdime) = J(idime,jdime) + coord(idime, ipoin_i) * deriv(jdime, inode, igaus, ielty)
                        end do
                    end do
                end do

                if (ndime == 1) then
                    detJ = J(1,1)
                else if (ndime == 2) then
                    detJ = J(1,1)*J(2,2) - J(1,2)*J(2,1)
                else
                    detJ = J(1,1)*(J(2,2)*J(3,3)-J(2,3)*J(3,2)) &
                         - J(1,2)*(J(2,1)*J(3,3)-J(2,3)*J(3,1)) &
                         + J(1,3)*(J(2,1)*J(3,2)-J(2,2)*J(3,1))
                endif

                dvol = weigp(igaus, ielty) * abs(detJ)

                ! Neighbouring elements share nodes -> atomic scatter
                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)
                    !$omp atomic update
                    b(ipoin_i) = b(ipoin_i) + shapf(inode, igaus, ielty) * source * dvol
                end do

            end do
        end do
        !$omp end target teams distribute parallel do

        ! Homogeneous Dirichlet BC: no load at fixed nodes
        !$omp target teams distribute parallel do
        do ipoin_i = 1, npoinLocal
            if (fixno(ipoin_i) == 1) b(ipoin_i) = 0.0_rp
        end do
        !$omp end target teams distribute parallel do

    end subroutine compute_B

    subroutine Apply_A(x, y)
        ! Matrix-free y = K*x of the Laplacian stiffness operator, with
        ! identity rows at the Dirichlet nodes. x and y are expected to be
        ! present on the device (outer data region): no transfers here.
        implicit none

        real(rp), intent(in)  :: x(:)
        real(rp), intent(out) :: y(:)

        integer(ip) :: ielem, inode, jnode, igaus, ielty, ispos
        integer(ip) :: ipoin_i, ipoin_j, pnode, idime, jdime
        real(rp)    :: J(3,3), invJ(3,3), detJ, dvol, k_ij
        real(rp)    :: gradI(3), gradJ(3)

        ! y = 0
        !$omp target teams distribute parallel do
        do ipoin_i = 1, size(y)
            y(ipoin_i) = 0.0_rp
        end do
        !$omp end target teams distribute parallel do

        ! Element loop
        !$omp target teams distribute parallel do                         &
        !$omp   private(J, invJ, gradI, gradJ, detJ, dvol, k_ij,          &
        !$omp           ielty, ispos, pnode, ipoin_i, ipoin_j,            &
        !$omp           inode, jnode, igaus, idime, jdime)
        do ielem = 1, nelem

            pnode = pnods(1) ! all elements are the same type here
            ielty = ltype(pnode)
            ispos = (ielem-1) * pnode

            do igaus = 1, ngaus(ielty)

                ! Jacobian
                J = 0.0_rp
                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)
                    do idime = 1, ndime
                        do jdime = 1, ndime
                            J(idime,jdime) = J(idime,jdime) + coord(idime, ipoin_i) * deriv(jdime, inode, igaus, ielty)
                        end do
                    end do
                end do

                ! detJ and inverse
                if (ndime == 1) then
                    detJ = J(1,1)
                    if (abs(detJ) > 1e-12_rp) then
                        invJ(1,1) = 1.0_rp/detJ
                    else
                        invJ(1,1) = 0.0_rp
                    endif
                else if (ndime == 2) then
                    detJ = J(1,1)*J(2,2) - J(1,2)*J(2,1)
                    if (abs(detJ) > 1e-12_rp) then
                        invJ(1,1) =  J(2,2)/detJ
                        invJ(1,2) = -J(1,2)/detJ
                        invJ(2,1) = -J(2,1)/detJ
                        invJ(2,2) =  J(1,1)/detJ
                    else
                        invJ = 0.0_rp
                    endif
                else
                    detJ = J(1,1)*(J(2,2)*J(3,3)-J(2,3)*J(3,2)) &
                         - J(1,2)*(J(2,1)*J(3,3)-J(2,3)*J(3,1)) &
                         + J(1,3)*(J(2,1)*J(3,2)-J(2,2)*J(3,1))
                    if (abs(detJ) > 1e-12_rp) then
                        invJ(1,1) =  (J(2,2)*J(3,3)-J(2,3)*J(3,2))/detJ
                        invJ(1,2) = -(J(1,2)*J(3,3)-J(1,3)*J(3,2))/detJ
                        invJ(1,3) =  (J(1,2)*J(2,3)-J(1,3)*J(2,2))/detJ
                        invJ(2,1) = -(J(2,1)*J(3,3)-J(2,3)*J(3,1))/detJ
                        invJ(2,2) =  (J(1,1)*J(3,3)-J(1,3)*J(3,1))/detJ
                        invJ(2,3) = -(J(1,1)*J(2,3)-J(1,3)*J(2,1))/detJ
                        invJ(3,1) =  (J(2,1)*J(3,2)-J(2,2)*J(3,1))/detJ
                        invJ(3,2) = -(J(1,1)*J(3,2)-J(1,2)*J(3,1))/detJ
                        invJ(3,3) =  (J(1,1)*J(2,2)-J(1,2)*J(2,1))/detJ
                    else
                        invJ = 0.0_rp
                    endif
                endif

                dvol = weigp(igaus, ielty) * abs(detJ)

                ! Element contributions K_ij * x_j
                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)

                    gradI = 0.0_rp
                    do idime = 1, ndime
                        do jdime = 1, ndime
                            gradI(jdime) = gradI(jdime) + invJ(idime,jdime) * deriv(idime, inode, igaus, ielty)
                        end do
                    end do

                    do jnode = 1, pnode
                        ipoin_j = lnods(ispos + jnode)

                        gradJ = 0.0_rp
                        do idime = 1, ndime
                            do jdime = 1, ndime
                                gradJ(jdime) = gradJ(jdime) + invJ(idime,jdime) * deriv(idime, jnode, igaus, ielty)
                            end do
                        end do

                        k_ij = 0.0_rp
                        do idime = 1, ndime
                            k_ij = k_ij + gradI(idime)*gradJ(idime)
                        end do

                        ! Neighbouring elements share nodes -> atomic scatter
                        !$omp atomic update
                        y(ipoin_i) = y(ipoin_i) + k_ij * x(ipoin_j) * dvol
                    end do
                end do

            end do
        end do
        !$omp end target teams distribute parallel do

        ! Homogeneous Dirichlet BC: identity rows for fixed nodes
        !$omp target teams distribute parallel do
        do ipoin_i = 1, npoinLocal
            if (fixno(ipoin_i) == 1) y(ipoin_i) = x(ipoin_i)
        end do
        !$omp end target teams distribute parallel do

    end subroutine Apply_A

    subroutine gpu_dot(x, y, n, result)
        ! Global dot product result = sum_i x(i)*y(i) over all MPI ranks.
        ! Local part on the GPU (x, y present on the device), global part
        ! with MPI_Allreduce of a single scalar on the host.
        use mpi
        implicit none

        real(rp),    intent(in)  :: x(:), y(:)
        integer(ip), intent(in)  :: n
        real(rp),    intent(out) :: result

        real(rp)    :: local
        integer(ip) :: i
        integer     :: mpierr

        local = 0.0_rp

        !$omp target teams distribute parallel do reduction(+:local) map(tofrom: local)
        do i = 1, n
            local = local + x(i) * y(i)
        end do
        !$omp end target teams distribute parallel do

        call MPI_Allreduce(local, result, 1, MPI_REAL8, MPI_SUM, a%MPIcomm, mpierr)

    end subroutine gpu_dot

    function wtime() result(t)
        ! Wall-clock time in seconds
        use mpi
        implicit none
        real(8) :: t
        t = MPI_Wtime()
    end function wtime

    function my_rank() result(rank_out)
        ! MPI rank in the problem communicator (only rank 0 prints)
        use mpi
        implicit none
        integer :: rank_out, mpierr
        call MPI_Comm_rank(a%MPIcomm, rank_out, mpierr)
    end function my_rank

end subroutine temgpu_solite