module geometry_types
    use iso_fortran_env, only: real64
    implicit none 

    private

    public :: centroid, dp

    integer, parameter :: dp = real64

    ! --- Definition of a derived type --- 
    type, public :: point
        real(dp) :: x
        real(dp) :: y
    end type point

    type, public :: triangle
        type(point) :: v1, v2, v3   ! a triangle has three vertices. 
    end type triangle

    contains 

    pure function centroid(tri) result(c)
        type(triangle), intent(in) :: tri
        type(point) :: c

        c%x = (tri%v1%x + tri%v2%x + tri%v3%x) / 3.0_dp
        c%y = (tri%v1%y + tri%v2%y + tri%v3%y) / 3.0_dp

    end function centroid

end module geometry_types


program derived_types
    use geometry_types
    !use iso_fortran_env, only: real64

    implicit none 
    !integer, parameter :: dp = real64

    type(point) :: p
    type(triangle) :: tri
    type(point) :: c

    ! --- Create and fill a point (access fields with %) ---
    p%x = 3.0_dp
    p%y = 4.0_dp
    ! also p = point(3.0_dp, 4.0_dp)

    print '(A, 2F8.2)', "Points p: ", p%x, p%y
    ! print '(A, 2F8.2)', "Points p: ", p

    ! --- A triangle made of three points ---
    tri%v1 = point(0.0_dp, 0.0_dp)
    tri%v2 = point(1.0_dp, 0.0_dp)
    tri%v3 = point(0.0_dp, 1.0_dp)

    ! tri = triangle(v1 = point(0.0_dp, 0.0_dp), & 
    !                v2 = point(1.0_dp, 0.0_dp), &
    !                v3 = point(0.0_dp, 1.0_dp))

    ! --- Access nested fields ---
    print '(A, 2F8.2)', "Vertex 1: ", tri%v1%x, tri%v1%y
    print '(A, *(F8.2))', "Vertex 2: ", tri%v2

    
    c = centroid(tri)
    print '(A, *(F8.2))', "Centroid of triangle: ", c
    

end program derived_types