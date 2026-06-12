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

    if (number >= 1 .and. number <= 9) then
        print '(A)', "Single positive number"
    end if

end program conditionals