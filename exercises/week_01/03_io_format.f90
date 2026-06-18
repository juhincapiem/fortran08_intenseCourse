program io_format
    implicit none

    integer :: n
    real :: x

    ! Prompt on the same line
    write(*, '(A)', advance = 'no') "Enter an integer: "
    read *, n
    write(*,'(A, I5.3)')"Your integer number is: ", n

    write(*, '(A)', advance = 'no') "Enter a real number: "
    read *, x
    print '(A,ES12.4)', "Your real number is: ", x

    ! If don't give enough space for the number, it would print ****

end program io_format