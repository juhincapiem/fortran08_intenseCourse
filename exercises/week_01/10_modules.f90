program modules
    use vector_utils
    implicit none

    integer :: length
    real :: normVector
    real, allocatable :: v(:)

    write(*, '(A)', advance = 'no')"How many elements does the vector have? "
    read *, length

    allocate(v(length))

    call fill_vector(v)
    call print_vector(v)

    normVector = norm(v)

    print *, "The norm of vector V is: ", normVector

    deallocate(v)

end program modules