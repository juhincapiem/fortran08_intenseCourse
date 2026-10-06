subroutine temgpu_solite(a)
    ! Matrix-free Conjugate Gradient solve of the steady temperature problem
    !     -div( grad(T) ) = f ,   f = 1 (constant source)
    ! with homogeneous Dirichlet boundary conditions (T = 0 on kfl_fixno == 1).
    ! No time derivative, single "time step" (this routine solves it once).
    use Mod_TemperatureGPU
    use typre
    implicit none

    class(TemperatureProblemGPU), target :: a

    integer(ip) :: nelem, ndime, npoinLocal, n
    integer(ip), pointer :: lnods(:), pnods(:), ltype(:), nnode(:), ngaus(:)
    integer(ip), pointer :: fixno(:)
    real(rp),    pointer :: coord(:,:), deriv(:,:,:,:), weigp(:,:), shapf(:,:,:)

    real(rp), allocatable :: u(:), b(:), r(:), p(:), Ap(:)

    integer(ip) :: k, maxit, ierr
    real(rp)    :: alpha, beta, denom, rdot, rdot_new, tol, sqrt_rdot_new

    write(*,*) "We are not going through php_solite, we have our own one."
    a%itera = a%itera + 1 ! usually done in php_solite

    ! ------------------------------------------------------------------
    ! Grab the mesh data we need from the framework
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
    shapf => a%Mesh%shape     ! ASSUMPTION: shape function values, same convention
                               ! as deriv: shapf(inode,igaus,ielty). Rename/replace
                               ! this line if your Mesh type calls it something else.

    fixno => a%kfl_fixno(1,:)

    ! ------------------------------------------------------------------
    ! CG working arrays and parameters
    ! ------------------------------------------------------------------
    n     = npoinLocal
    maxit = 1000
    tol   = 1.0e-8_rp
    ierr  = 0

    allocate(u(n), b(n), r(n), p(n), Ap(n))
    u = 0.0_rp   ! initial guess: zero everywhere (also satisfies the
                 ! homogeneous Dirichlet BC exactly at the fixed nodes)

    call compute_B(b)

    ! r = b - A*u   (u = 0 here, so this is really just r = b, but this
    ! form is kept in case you later want a nonzero initial guess)

    !$omp target data map(to: lnods, coord, deriv, weigp, ltype, pnods, ngaus, fixno)
    call Apply_A(u, Ap)
    r = b - Ap
    p = r

    !call MPIdotAllReduce(r, r, n, rdot, a%MPIcomm)
    if (rdot < 0.0_rp) rdot = 0.0_rp

    ierr = 1   ! assume non-convergence until we break out below

    
    do k = 1, maxit

        ! 3 loops offloaded
        call Apply_A(p, Ap)

        ! denom = (p, Ap)
        call MPIdotAllReduce(p, Ap, n, denom, a%MPIcomm)
        if (abs(denom) < 1.0e-30_rp) then
            ierr = 2
            exit
        endif
        alpha = rdot / denom

        ! u = u + alpha*p
        u = u + alpha * p

        ! r = r - alpha*Ap
        r = r - alpha * Ap

        call MPIdotAllReduce(r, r, n, rdot_new, a%MPIcomm)

        sqrt_rdot_new = sqrt(rdot_new)
        write(*,*) "CG iteration ", k, " residual norm = ", sqrt_rdot_new
        if (sqrt_rdot_new < tol) then
            ierr = 0
            exit
        endif

        beta = rdot_new / rdot
        p    = r + beta * p
        rdot = rdot_new

    end do
    !$omp end target data

    write(*,*) "CG finished with ierr = ", ierr, " after ", k, " iterations."
    a%unkno(1,1:npoinLocal) = u

    deallocate(u, b, r, p, Ap)

contains

    subroutine compute_B(b)
        ! Assembles b_i = integral_domain  N_i * f  dV ,  f = 1 (constant),
        ! then zeroes it at the fixed (Dirichlet) nodes.
        use typre
        implicit none

        real(rp), intent(out) :: b(:)

        integer(ip) :: ielem, inode, igaus, ielty, ispos, ipoin_i, pnode
        integer(ip) :: idime, jdime
        real(rp)    :: J(3,3), detJ, dvol
        real(rp), parameter :: source = 1.0_rp

        b = 0.0_rp

        do ielem = 1, nelem

            pnode = pnods(1) ! because it's all the same elements here
            ielty = ltype(pnode)
            ispos = (ielem-1) * pnode

            do igaus = 1, ngaus(ielty)

                ! Jacobian J(k,l) = SUM_nodes coord(k,node) * deriv(l,node,igaus,ielty)
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
        ! Matrix-free action y = K*x of the Laplacian stiffness operator,
        ! with homogeneous-Dirichlet rows replaced by the identity so that
        ! x(fixed) stays pinned at 0 throughout the CG iteration.
        use typre

        implicit none

#ifdef CRAYPAT
#include "pat_apif.h"
#endif

        real(rp), intent(in)  :: x(:)
        real(rp), intent(out) :: y(:)

        integer(ip) :: ielem, inode, jnode, igaus, ielty, ispos
        integer(ip) :: ipoin_i, ipoin_j, pnode, idime, jdime
        real(rp)    :: J(3,3), invJ(3,3), detJ, dvol, k_ij
        real(rp)    :: gradI(3), gradJ(3)
        integer(ip) :: istat
#ifdef CRAYPAT
Call PAT_region_begin(4, "Global Loop", istat)
#endif        
        !$omp target data map(to: x) map(from: y)
#ifdef CRAYPAT
Call PAT_region_begin(1, "first Loop", istat)
#endif
        !$omp target teams distribute parallel do
        do ipoin_i = 1, size(y)
            y(ipoin_i) = 0.0_rp
        end do
        !$omp end target teams distribute parallel do
#ifdef CRAYPAT
Call PAT_region_end(1,istat)
#endif


#ifdef CRAYPAT
Call PAT_region_begin(2, "Second Loop", istat)
#endif
        ! loop over all the elements
        !$omp target teams distribute parallel do                         &
        !$omp   private(J, invJ, gradI, gradJ, detJ, dvol, k_ij,          &
        !$omp           ielty, ispos, pnode, ipoin_i, ipoin_j,            &
        !$omp           inode, jnode, igaus, idime, jdime)
        do ielem = 1, nelem

            pnode = pnods(1) ! because it's all the same elements here
            ielty = ltype(pnode)
            ispos = (ielem-1) * pnode

            do igaus = 1, ngaus(ielty)

                ! build Jacobian J(k,l) = SUM_nodes coord(k,node) * deriv(l,node,igaus,ielty)
                J = 0.0_rp
                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)
                    do idime = 1, ndime
                        do jdime = 1, ndime
                            J(idime,jdime) = J(idime,jdime) + coord(idime, ipoin_i) * deriv(jdime, inode, igaus, ielty)
                        end do
                    end do
                end do


                ! compute detJ and inverse (small dim 1..3)
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
                    ! 3x3 inverse via cofactors
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

                ! compute contributions K_ij and apply K*x -> for each local pair
                do inode = 1, pnode
                    ipoin_i = lnods(ispos + inode)

                    ! compute grad phi_i (cartesian)
                    gradI = 0.0_rp
                    do idime = 1, ndime
                        do jdime = 1, ndime
                            gradI(jdime) = gradI(jdime) + invJ(idime,jdime) * deriv(idime, inode, igaus, ielty)
                        end do
                    end do

                    do jnode = 1, pnode
                        ipoin_j = lnods(ispos + jnode)

                        ! compute grad phi_j (cartesian)
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

                        !$omp atomic update
                        y(ipoin_i) = y(ipoin_i) + k_ij * x(ipoin_j) * dvol
                    end do
                end do

            end do
        end do
        !$omp end target teams distribute parallel do
#ifdef CRAYPAT
Call PAT_region_end(2,istat)
#endif

        ! Homogeneous Dirichlet BC: identity rows for fixed nodes.
        ! b(fixed) = 0 and u(fixed) = 0 initially, so x(fixed) stays at 0
        ! throughout the whole CG iteration; forcing y(fixed) = x(fixed)
        ! here just keeps that consistent without touching the
        ! off-diagonal terms assembled above (which see x(fixed) = 0 anyway).

#ifdef CRAYPAT
Call PAT_region_begin(3, "Thrid loop", istat)
#endif
        !$omp target teams distribute parallel do
        do ipoin_i = 1, npoinLocal
            if (fixno(ipoin_i) == 1) y(ipoin_i) = x(ipoin_i) 
        end do
        !$omp end target teams distribute parallel do
#ifdef CRAYPAT
Call PAT_region_end(3,istat)
#endif
        !$omp end target data
#ifdef CRAYPAT
Call PAT_region_end(4,istat)
#endif

    end subroutine Apply_A

end subroutine temgpu_solite
