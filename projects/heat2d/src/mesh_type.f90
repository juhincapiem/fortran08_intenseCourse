module mesh_type
    use iso_fortran_env, only: real64
    implicit none 

    private 

    integer, parameter :: dp = real64

    public :: dp, mesh

    ! --- The mesh class: groups all the mesh data in a sinlge entity ---

    type mesh
        real(dp), allocatable :: node_matrix(:,:)           ! x,y and z coordinates 
        integer, allocatable :: connect_matrix(:,:)         ! nodes' id of each element
        integer, allocatable :: boundary_matrix(:,:)        ! boundary nodes

        integer :: n_nodes = 0
        integer :: n_elem = 0
        integer :: n_boundaries = 0

        !    type 1 (line) = 2 nodes, type 2 (triangle) = 3 nodes, etc.
        integer, parameter ::  nodes_per_type(3) = &
        [2, 3, 4]


        contains

        procedure :: read_mesh
        procedure, private :: read_nodes
        procedure, private :: read_elem

    end type mesh

    contains


    subroutine read_mesh(self, file_name)
        class(mesh), intent(inout) :: self

        character(len=*), intent(in) :: file_name
        integer :: unit_num, ios

        ! open the file (the orchestrator owns it)
        open(newunit = unit_num, file = file_name, status = "old", action = "read", iostat = ios)
        if (ios /= 0) then
            print '(A,A)', "Error! cannot open the file: ", trim(file_name)
            stop
        end if

        ! delegate: each method reads its part from the open file
        call read_nodes(self, unit_num, ios)


        close(unit_num)
    end subroutine read_mesh


    subroutine read_nodes(self,unit_num,ios)
        class(mesh), intent(inout) :: self
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios

        integer :: id, i
        real :: x, y, z
        character(len = 200) :: line

        call find_section(unit_num, ios, "$Nodes")

        read(unit_num, *) self%n_nodes

        Allocate(self%node_matrix(self%n_nodes,3))

        do i = 1, self%n_nodes
            read(unit_num, *) id, x, y, z

            if (i /= id) then
                print '(A,I0,A,I0)', "Node", id, "doesn't match with the row number i =",i
                stop
            end if

            self%node_matrix(id, 1) = x
            self%node_matrix(id, 2) = y
            self%node_matrix(id, 3) = z
        end do

        read(unit_num, '(A)', iostat = ios) line
        if (trim(line) == "$EndNodes") then
            print '(A)', "All the nodes' coordinates have been read and written"
        else 
            print '(A)', "Error: expected $EndNodes, mesh may be malformed"
            stop
        end if 

    end subroutine read_nodes


    subroutine read_elem(self,unit_num, ios)
        class(mesh), intent(inout) :: self
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios





    end subroutine read_elem



    subroutine find_section(unit_num, ios, section_name)
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios
        character(len = *), intent(in) :: section_name

        character(len = 200) :: line

        do 
            read(unit_num, '(A)', iostat = ios) line
            if (ios /= 0) return
            if (trim(line) == trim(section_name)) exit
            
        end do
    end subroutine find_section

end module mesh_type