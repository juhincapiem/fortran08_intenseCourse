program portable_precision

    ! portable way, which does not depend on the compiler
    use iso_fortran_env, only: real64
    implicit none 
    
    ! A shorter way to define real64
    integer, parameter ::  dp = real64  ! dp = "double precision"

    real(real64), allocatable :: node_matrix_01(:,:)
    real(dp), allocatable :: node_matrix_02(:,:)

    integer :: unit_num, ios, n_nodes, id, i

    character(len = 200) :: file_name, line

    file_name = "./projects/heat2d/mesh/unit_square.msh"

    open(newunit = unit_num, file = file_name, status = "old", action = "read", iostat = ios)


    do 
        read(unit_num, '(A)') line

        if (trim(line) == "$Nodes") exit

    end do 

    read(unit_num, *) n_nodes

    allocate(node_matrix_01(n_nodes, 3))
    allocate(node_matrix_02(n_nodes, 3))

    do i = 1, n_nodes
        read(unit_num, *) id, node_matrix_01(i, 1), node_matrix_01(i, 2), node_matrix_01(i, 3)
        print '(*(F12.4))', node_matrix_01(i, :)
    end do


end program portable_precision