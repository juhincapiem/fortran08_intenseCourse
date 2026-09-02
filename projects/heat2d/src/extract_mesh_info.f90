module extract_mesh_info
    implicit none
    private

    public :: find_section, read_nodes, read_elements

    contains

    ! --- Subroutine to read and find specific sections ---
    subroutine find_section(unit_num, ios, section_name)
        integer, intent(in) :: unit_num
        integer, intent(out) :: ios
        character(len = 200) :: line
        character(len=*), intent(in) :: section_name

        do  
            read(unit_num, '(A)', iostat = ios) line

            if (ios /= 0) return 

            if (trim(line) == trim(section_name)) exit
        end do

    end subroutine find_section


    ! --- Subroutine to create node matrix ---
    subroutine read_nodes(file_name, node_matrix, n_nodes) 
        character(len=*), intent(in) :: file_name
        real, allocatable, intent(out) :: node_matrix(:,:)
        integer, intent(out) :: n_nodes

        character(len=200) :: section_name, line
        integer :: unit_num, ios, id, i

        section_name = '$Nodes'

        ! 1. Open file:
        open(newunit = unit_num, file = file_name, status = "old", action = "read", iostat = ios)

        if (ios /= 0) then
            print '(A)', "Error: cannot open file"
            stop
        end if

        ! 2. Search nodes
        call find_section(unit_num, ios, section_name)
        if (ios /= 0) then 
            print '(A)', "Error: section not found: ", trim(section_name)
            stop
        end if

        ! 3. Read number of nodes
        read(unit_num, *) n_nodes

        ! 4. Allocate
        Allocate(node_matrix(n_nodes,3))

        ! 5. read and write
        do i = 1, n_nodes
            read(unit_num, *)id, node_matrix(i,1), node_matrix(i,2), node_matrix(i,3)
        end do

        read(unit_num, '(A)', iostat = ios) line
        if (trim(line) == "$EndNodes") then
            print '(A)', "All the nodes' coordinates have been read and written"
        else 
            print '(A)', "Error: expected $EndNodes, mesh may be malformed"
            stop
        end if 

        ! 6. Close
        close(unit_num)

        ! 7. Check
        print '(A,I0)', "Number of nodes: ", n_nodes

        do i = 1, n_nodes 
            print '(I3, *(F12.4))', i, node_matrix(i,:)
        end do

    end subroutine read_nodes



    subroutine count_elements(unit_num, n_elements, count_boundary, count_domain)
        integer, intent(in) :: unit_num
        integer, intent(out) :: n_elements, count_boundary, count_domain
        integer :: i, id, elem_type

        read(unit_num,*) n_elements

        count_boundary = 0
        count_domain = 0

        do i = 1, n_elements
            read(unit_num,*) id, elem_type

            if (elem_type == 1) then 
                count_boundary =  count_boundary + 1

            else if (elem_type == 2) then
                count_domain = count_domain + 1 

            else
                print '(A)', "Those elements type were not recognized"

            end if 

        end do


    end subroutine count_elements



    ! --- Subroutine to create connectivity and boundary matrix ---
    subroutine read_elements(file_name, connectivity_matrix, boundary_matrix)
        character(len = *), intent(in) :: file_name
        integer, allocatable, intent(out) :: connectivity_matrix(:,:), boundary_matrix(:,:)

        integer :: unit_num, ios, i, n_elements, i_boundary, i_domain
        integer :: count_boundary, count_domain
        integer :: id, etype, ntags, tag1, tag2
        character(len = 200) :: line

        i_boundary = 0
        i_domain = 0

        open(newunit = unit_num, file = file_name, status = "old", action = "read", iostat = ios)

        if (ios /= 0) then
            print '(A)', "Error: cannot open de file"
            stop
        end if

        call find_section(unit_num, ios, "$Elements")

        if (ios /= 0) then
            print '(A)', "Error: section not found: $Elements"
            stop
        end if 

        call count_elements(unit_num, n_elements, count_boundary, count_domain)

        allocate(boundary_matrix(count_boundary, 4))
        allocate(connectivity_matrix(count_domain, 5))

        ! Rewind to re start at $Elements
        rewind(unit_num)
        call find_section(unit_num, ios, "$Elements")
        
        ! Read the element number line, which is useless right now
        read(unit_num, *)
        do i = 1, n_elements

            read(unit_num,'(A)') line
            read(line, *) id, etype

            if (etype == 1) then
                i_boundary = i_boundary + 1
                read(line, *) id, etype, ntags, tag1, tag2, &
                boundary_matrix(i_boundary, 1), &
                boundary_matrix(i_boundary, 2)
                boundary_matrix(i_boundary, 3) = tag1
                boundary_matrix(i_boundary, 4) = id

            else if (etype == 2) then
                i_domain = i_domain + 1
                read(line, *) id, etype, ntags, tag1, tag2, &
                connectivity_matrix(i_domain, 1), &
                connectivity_matrix(i_domain, 2), &
                connectivity_matrix(i_domain, 3)
                connectivity_matrix(i_domain, 4) = tag1
                connectivity_matrix(i_domain, 5) = id
            end if
        end do

        close(unit_num)

        do i = 1, count_boundary
            print '(*(I6))', boundary_matrix(i, :)
        end do

        do i = 1, count_domain
            print '(*(I6))', connectivity_matrix(i,:)
        end do

    end subroutine read_elements


end module extract_mesh_info
