program conditionals
    implicit none

    integer :: number

    write(*, '(A)', advance = 'no') "Enter an integer: "
    read *, number

    if (number > 0 .and. mod(number,2)==0 ) then
        print '(A)', "The number is positive and even"

    else if (number > 0 .and. mod(number,2)==1 ) then
        print '(A)', "The number is positive and odd"

    else if (number < 0 .and. mod(number,2)==0  ) then
        print '(A)', "The number is negative and even"

    else if (number < 0 .and. mod(number,2)==1  ) then
        print '(A)', "The number is negative and odd"

    else 
        print '(A)', "The number is zero"

    end if

end program conditionals