program procedures_demo
    implicit none

    integer :: length
    real :: normVector
    real, allocatable :: v(:)

    write(*, '(A)', advance = 'no') "How Long is the vector: "
    read *, length

    allocate(v(length)) 

    ! Lets call the subroutine
    call fill_vector(v)
    call print_vector(v)

    ! Lets call the fucntion 
    normVector = norm(v)

    write(*,*) "The norm of the vector is: ", normVector


    contains

    subroutine fill_vector(x)
        real, intent(out) :: x(:)
        integer :: i

        do i = 1, size(x), 1
            x(i) = i
        end do

    end subroutine fill_vector

    subroutine print_vector(x)
        real, intent(in) :: x(:)

        print '(*(F8.1))', x
        
    end subroutine  print_vector

    function norm(x) result(n)
        real, intent(in) :: x(:)
        real :: n
        n = sqrt(sum(x**2))
    end function norm


end program procedures_demo  