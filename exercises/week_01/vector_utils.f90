module vector_utils
    implicit none
    private

    public:: fill_vector, print_vector, norm

    contains 

    subroutine fill_vector(x)
        real, intent(out) :: x(:)
        integer :: i

        do i = 1, size(x)
            x(i) = real(i)
        end do

    end subroutine fill_vector

    subroutine print_vector(x)
        real, intent(in) :: x(:)

        print '(*(F6.1))', x
        
    end subroutine

    function norm(x) result(n)
        real, intent(in) :: x(:)
        real :: n

        n = sqrt(sum(x**2))

    end function norm

end module vector_utils