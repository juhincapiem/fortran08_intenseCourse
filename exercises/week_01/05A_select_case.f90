program select_case
    implicit none

    integer :: score

    write(*, '(A)', advance='no')'Enter a score (0-100): '
    read *, score

    select case (score)
    case (90:100)
        print '(A)', "Grade: A"
    case (80:89)
        print '(A)', "Grade: B"
    case (70:79)
        print '(A)', "Grade: C"
    case (60:69)
        print '(A)', "Grade: D"
    case (0:59)
        print '(A)', "Grade: F"
    case default 
        print '(A)', "Invalid score (out of range)"
    end select


end program select_case