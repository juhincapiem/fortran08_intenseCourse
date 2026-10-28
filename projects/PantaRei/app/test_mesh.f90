program test_mesh
    use extract_mesh_info
    implicit none

    real, allocatable :: node_matrix(:,:)
    integer, allocatable :: connectivity_matrix(:,:), boundary_matrix(:,:)
    character(len=100) :: file_name
    integer :: n_nodes

    file_name = './mesh/unit_square.msh'

    call read_nodes(file_name, node_matrix, n_nodes)
    call read_elements(file_name, connectivity_matrix, boundary_matrix)



end program test_mesh 