program select_letters
    implicit none

    character :: grade

    write(*, '(A)', advance = 'no') 'Enter your grade: '
    read *, grade

    select case (grade)
    case ('A')
        print '(A)', "Excellent"
    case ('B', 'C')
        print '(A)', "Good"
    case default
        print '(A)', "Terrible"
    end select

end program select_letters