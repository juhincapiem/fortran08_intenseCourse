module geometry_types
    use iso_fortran_env, only: real64
    implicit none  

    private

    public :: dp

    integer, parameter :: dp = real64

    type, abstract, public :: element
    contains
        procedure(measure_iface), deferred :: measure   ! HOLE
        procedure :: report                             ! ALREADY DONE

    end type element

    abstract interface
        function measure_iface(self) result(measure)
            import element, dp
            class(element), intent(in) :: self
            real(dp) :: measure
        end function measure_iface
    end interface

    type, public :: point
        real(dp) :: x
        real(dp) :: y
    end type point


    type, public, extends(element) :: triangle
        type(point) :: v1, v2, v3

        contains
            procedure :: measure => triangle_area
            procedure :: centroid    

    end type triangle

    contains 

    function triangle_area(self) result(area)
        class(triangle), intent(in) :: self
        real(dp) :: area

        area = 0.5_dp*abs(self%v1%x*(self%v2%y - self%v3%y) + &
                    self%v2%x*(self%v3%y - self%v1%y) + &
                    self%v3%x*(self%v1%y - self%v2%y))

    end function triangle_area

    subroutine report(self)
        class(element), intent(in) :: self
        print '(A, F8.3)', "MEASURE = ", self%measure()
    end subroutine report


    pure function centroid(self) result(c)
        class(triangle), intent(in) :: self
        type(point) :: c

        c%x = (self%v1%x + self%v2%x + self%v3%x) / 3.0_dp
        c%y = (self%v1%y + self%v2%y + self%v3%y) / 3.0_dp

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
    print '(A, *(F8.2))', "Vertex 3: ", tri%v3


    
    ! c = centroid(tri)
    c = tri%centroid()
    print '(A, *(F8.2))', "Centroid of triangle: ", c

    ! area
    !print *, tri%measure()
    call tri%report()
    

end program derived_types