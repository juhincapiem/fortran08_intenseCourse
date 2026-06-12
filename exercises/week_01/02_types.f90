program types_demo
    implicit none

    integer :: count
    real :: temperature
    real(kind=8) :: precise_pi
    logical :: is_ready
    character(len=20) :: name

    count = 42
    temperature = 36.6
    precise_pi = 3.141592653589793d0 !If really want double precision, you must write d0 at the end
    is_ready = .true.
    name = "Fortran"

    print *, "count:            ", count
    print *, "temperature:      ", temperature
    print *, "precise_pi:       ", precise_pi
    print *, "is_ready:         ", is_ready
    print *, "name:             ", name

end program