program arrays
    implicit none

    integer :: i 
    real :: v(10), w(10)

    ! Fill v with 1.0, 2.0, ..., 10.0 using an implied do
    v = [(real(i), i = 1, 10)]

    ! Whole array operation: no loop needed
    w = v**2

    print '(A)', "Vector v:"
    print '(10F7.1)', v

    print '(A)', "v squared w:"
    print '(*(F7.1))', w

    print '(A, F8.2)', "Sum of w: ", sum(w)
    print '(A, F8.2)', "Max of w: ", maxval(w)
    print '(A, F8.2)', "Mean of w", sum(w)/size(w) 

    print '(A)', "Even-indexed elements of v (v(2:10:2))"
    print '(5F7.1)', v(2:10:2)

    print '(A)', "Elements of v greater than 5:"
    print '(*(F7.1))', pack(v, v>5.0)


end program arrays