program matrices
    implicit none

    integer :: i, j
    real :: A(3,3), x(3), b(3)

    ! Fill a 3x3 matrix
    do i = 1, 3, 1
        do j = 1, 3, 1
            A(i, j) = real(i * 10 + j)

        end do
    end do

    do i = 1, 3, 1
        x(i) = real(i)
    end do


    print '(A)', "Matrix A: "

    do i = 1, 3
        print '(*(F8.1))', A(i,:)
    end do

    ! Print 
    print '(A)', "Vector x:"
    print '(*(F7.1))', x

    b = matmul(A,x)
    print '(A)', "b = A*x (matmul)"
    print '(3F8.1)', b


    print '(A, I0, A, I0)', "Shape of A: ", size(A, 1), " x ", size(A,2)


end program matrices