program loops_for
    implicit none

    integer :: n, i 
    integer :: a, b, temp

    write(*, '(A)', advance = 'no') "How many Fibonacci numbers? "
    read *, n

    a = 0
    b = 1

    do i = 1, n, 1

        temp = a + b

        print '(I0, A, I0, A, I0)', a, " + ", b, " = ", temp

        a = b
        b = temp

    end do

end program loops_for