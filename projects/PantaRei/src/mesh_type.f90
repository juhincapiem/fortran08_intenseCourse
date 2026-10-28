module mesh_type
    use iso_fortran_env, only: real64
    implicit none 

    private 

    integer, parameter :: dp = real64

    public :: dp, mesh

    !    type 1 (line) = 2 nodes
    !    type 2 (triangle) = 3 nodes
    !    type 3 (quadrilateral) = 4 nodes

    integer, parameter ::  nodes_per_type(3) = &
    [2, 3, 4]

    ! --- The mesh class: groups all the mesh data in a sinlge entity ---

    type mesh
        real(dp), allocatable :: node_matrix(:,:)           ! x,y and z coordinates 
        integer, allocatable :: connectivity_matrix(:,:)         ! nodes' id of each element
        integer, allocatable :: boundary_matrix(:,:)        ! boundary nodes

        integer :: n_nodes = 0
        integer :: n_elem = 0
        integer :: n_boundaries = 0


        contains

        procedure :: read_mesh
        procedure, private :: read_nodes
        procedure, private :: read_elem

    end type mesh

    contains


    subroutine read_mesh(self, file_name, ios, errmsg)
        class(mesh), intent(inout) :: self
        character(len=*), intent(in) :: file_name
        integer, intent(out) :: ios
        character(len=*), intent(out) :: errmsg

        integer :: unit_num

        ! open the file (the orchestrator owns it)
        open(newunit = unit_num, file = file_name, status = "old", action = "read", iostat = ios, iomsg=errmsg)
        if (ios /= 0) then
            errmsg = "could not open " // trim(file_name) // ": " // trim(errmsg)
            return
        end if

        ! delegate: each method reads its part from the open file

        ! First, lets build the node_matrix ---> x, y and z position of each node
        call self%read_nodes(unit_num, ios, errmsg)
        if (ios /= 0) return

        ! Then, lets build the boundary and the connectivity matrix
        call self%read_elem(unit_num, ios, errmsg)


        close(unit_num)
    end subroutine read_mesh


    subroutine read_nodes(self, unit_num, ios, errmsg)
        class(mesh), intent(inout) :: self
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios
        character(len=*), intent(out) :: errmsg

        integer :: id, i
        character(len=200) :: line

        errmsg = ""

        ! Find the line where $Nodes begin
        call find_section(unit_num, ios, "$Nodes")
        if (ios /= 0) then
            errmsg = "section $Nodes not found"
            return
        end if

        ! First line is the numbers of nodes
        read(unit_num, *, iostat=ios, iomsg=errmsg) self%n_nodes
        if (ios /= 0) return

        ! With number of nodes we can allocate the node_matrix
        allocate(self%node_matrix(self%n_nodes, 3))

        ! Fill the whole node matrix with the coordinates
        do i = 1, self%n_nodes
            read(unit_num, *, iostat=ios, iomsg=errmsg) id, self%node_matrix(i, :)
            if (ios /= 0) return

            if (id /= i) then
                ios = 1
                write(errmsg, '(A,I0,A,I0)') "node id ", id, " found at row ", i
                return
            end if
        end do

        read(unit_num, '(A)', iostat=ios, iomsg=errmsg) line
        if (ios /= 0) return

        if (trim(line) /= "$EndNodes") then
            ios = 1
            errmsg = "expected $EndNodes, found: " // trim(line)
        end if
        
    end subroutine read_nodes


    subroutine read_elem(self,unit_num,ios,errmsg)
        class(mesh), intent(inout) :: self
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios
        character(len=*), intent(out) :: errmsg

        integer :: i, n_boundary_elem, n_internal_elem

        errmsg = ""

        n_boundary_elem = 0
        n_internal_elem = 0

        ! Find the line where $Elements begin
        call find_section(unit_num, ios, "$Elements")
        if (ios /= 0) then
            errmsg = "section $Elements not found"
            return
        end if

        ! First line is the number of elements (internal and boundary ones)
        read(unit_num, *, iostat=ios, iomsg=errmsg)  self%n_elem
        if (ios /= 0) return

        ! Fill  both matrix at the "same time":
        do i = 1, self%n_elem
            read(unit_num, iostat=ios, iomsg=errmsg)
            if (ios /= 0) return

            


        end do






    end subroutine read_elem



    subroutine find_section(unit_num, ios, section_name)
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios
        character(len = *), intent(in) :: section_name

        character(len = 200) :: line

        do 
            read(unit_num, '(A)', iostat = ios) line
            if (ios /= 0) return                         ! end of file or read error
            if (trim(line) == trim(section_name)) exit   ! Read until find the section name
            
        end do
    end subroutine find_section

end module mesh_type