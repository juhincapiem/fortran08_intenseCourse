subroutine temgpu_solite(a)
    ! ------------------------------------------------------------------
    ! CPU reference version (sequential, no OpenMP, no CrayPat regions).
    !
    ! Matrix-free Conjugate Gradient solve of the steady temperature problem
    !     -div( grad(T) ) = f ,   f = 1 (constant source)
    ! with homogeneous Dirichlet boundary conditions (T = 0 on kfl_fixno == 1).
    !
    ! Timing: MPI_Wtime around each phase. One "TIMING" line is printed at
    ! the end with the same fields as the GPU version, so both outputs can
    ! be parsed the same way (t_init and t_exit are 0 here: no device).
    ! ------------------------------------------------------------------
    use Mod_TemperatureGPU
    use typre
    implicit none

    class(TemperatureProblemGPU), target :: a

    ! .true.  -> print the residual every iteration (validation runs)
    ! .false. -> only the final summary (timing runs: per-iteration I/O
    !            would add to the measured CG time)
    logical, parameter :: print_residuals = .false.

    integer(ip) :: nelem, ndime, npoinLocal, n
    integer(ip), pointer :: lnods(:), pnods(:), ltype(:), nnode(:), ngaus(:)
    integer(ip), pointer :: fixno(:)
    real(rp),    pointer :: coord(:,:), deriv(:,:,:,:), weigp(:,:), shapf(:,:,:)

    real(rp), allocatable :: u(:), b(:), r(:), p(:), Ap(:)

    integer(ip) :: k, maxit, ierr, niter
    integer     :: rank
    real(rp)    :: alpha, beta, denom, rdot, rdot_new, tol, sqrt_rdot_new

    ! Timers (seconds)
    real(8) :: t0, t1, t2, t3, t4, ta
    real(8) :: t_rhs, t_cgsetup, t_cg, t_apply, t_total

    rank = my_rank()
    t0   = wtime()

    if (rank == 0) write(*,*) "temgpu_solite: CPU reference version"
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

    fixno => a%kfl_fixno(1,:)

    write(*,'(a,i10,a,i10)') " MESH nelem=", nelem, " npoin=", npoinLocal


    ! ------------------------------------------------------------------
    ! CG working arrays and parameters
    ! ------------------------------------------------------------------
    n     = npoinLocal
    maxit = 1000
    tol   = 1.0e-8_rp
    ierr  = 0

    allocate(u(n), b(n), r(n), p(n), Ap(n))
    u = 0.0_rp   ! initial guess (also satisfies the homogeneous Dirichlet BC)

    ! ------------------------------------------------------------------
    ! Right-hand side
    ! ------------------------------------------------------------------
    t1 = wtime()
    call compute_B(b)
    t2 = wtime()
    t_rhs = t2 - t1

    ! ------------------------------------------------------------------
    ! CG setup: r = b - A*u, p = r, rdot = r.r
    ! ------------------------------------------------------------------
    call Apply_A(u, Ap)
    r = b - Ap
    p = r

    call MPIdotAllReduce(r, r, n, rdot, a%MPIcomm)
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

        call MPIdotAllReduce(p, Ap, n, denom, a%MPIcomm)
        if (abs(denom) < 1.0e-30_rp) then
            ierr = 2
            exit
        endif
        alpha = rdot / denom

        u = u + alpha * p
        r = r - alpha * Ap

        call MPIdotAllReduce(r, r, n, rdot_new, a%MPIcomm)

        sqrt_rdot_new = sqrt(rdot_new)
        if (print_residuals .and. rank == 0) then
            write(*,*) "CG iteration ", k, " residual norm = ", sqrt_rdot_new
        endif
        if (sqrt_rdot_new < tol) then
            ierr = 0
            exit
        endif

        beta = rdot_new / rdot
        p    = r + beta * p
        rdot = rdot_new
    end do

    t4 = wtime()
    t_cg = t4 - t3

    a%unkno(1,1:npoinLocal) = u
    t_total = wtime() - t0

    ! ------------------------------------------------------------------
    ! Summary (same fields as the GPU version)
    ! ------------------------------------------------------------------
    if (rank == 0) then
        write(*,*) "CG finished with ierr = ", ierr, " after ", niter, &
                   " iterations. Final residual = ", sqrt_rdot_new
        write(*,'(a,i6,8(a,es12.5))') " TIMING version=CPU iters=", niter, &
            " t_total=",           t_total,                    &
            " t_init=",            0.0d0,                      &
            " t_rhs=",             t_rhs,                      &
            " t_cgsetup=",         t_cgsetup,                  &
            " t_cg=",              t_cg,                       &
            " t_cg_per_iter=",     t_cg    / max(niter, 1_ip), &
            " t_applyA_per_call=", t_apply / max(niter, 1_ip), &
            " t_exit=",            0.0d0
    endif

    deallocate(u, b, r, p, Ap)

contains

    subroutine compute_B(b)
        ! b_i = integral N_i * f dV, f = 1, then zeroed at Dirichlet nodes.
        implicit none

        real(rp), intent(out) :: b(:)

        integer(ip) :: ielem, inode, igaus, ielty, ispos, ipoin_i, pnode
        integer(ip) :: idime, jdime
        real(rp)    :: J(3,3), detJ, dvol
        real(rp), parameter :: source = 1.0_rp

        b = 0.0_rp

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

                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)
                    b(ipoin_i) = b(ipoin_i) + shapf(inode, igaus, ielty) * source * dvol
                end do

            end do
        end do

        ! Homogeneous Dirichlet BC: no load at fixed nodes
        do ipoin_i = 1, npoinLocal
            if (fixno(ipoin_i) == 1) b(ipoin_i) = 0.0_rp
        end do

    end subroutine compute_B

    subroutine Apply_A(x, y)
        ! Matrix-free y = K*x of the Laplacian stiffness operator, with
        ! identity rows at the Dirichlet nodes.
        implicit none

        real(rp), intent(in)  :: x(:)
        real(rp), intent(out) :: y(:)

        integer(ip) :: ielem, inode, jnode, igaus, ielty, ispos
        integer(ip) :: ipoin_i, ipoin_j, pnode, idime, jdime
        real(rp)    :: J(3,3), invJ(3,3), detJ, dvol, k_ij
        real(rp)    :: gradI(3), gradJ(3)

        y = 0.0_rp

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

                        y(ipoin_i) = y(ipoin_i) + k_ij * x(ipoin_j) * dvol
                    end do
                end do

            end do
        end do

        ! Homogeneous Dirichlet BC: identity rows for fixed nodes
        do ipoin_i = 1, npoinLocal
            if (fixno(ipoin_i) == 1) y(ipoin_i) = x(ipoin_i)
        end do

    end subroutine Apply_A

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