program conditionals
    implicit none

    integer :: number

    write(*, '(A)', advance = 'no') "Enter an integer: "
    read *, number

    if (number > 0) then
        print '(A)', "The number is positive"
    else if (number < 0) then
        print '(A)', "The number is negative"
    else 
        print '(A)', "The number is zero"

    end if

end program conditionals