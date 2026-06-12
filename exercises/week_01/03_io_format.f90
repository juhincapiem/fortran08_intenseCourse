program control_demo
    implicit none

    integer :: n
    real :: x

    ! Prompt on the same line
    write(*, '(A)', advance = 'no') "Enter an integer: "
    read *, n
    write(*,'(A, I0)')"Your integer number is: ", n

    write(*, '(A)', advance = 'no') "Enter a real number: "
    read *, x
    print '(A,F8.3)', "Your real number is: ", x

    

end program