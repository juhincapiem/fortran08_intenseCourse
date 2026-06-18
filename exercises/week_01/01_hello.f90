program hello     ! All executable Fortran program needs a "program" block with a name
    implicit none ! Always write this code line. This disables a weird and old
                  ! fashion rule  
    print *, "Hello Fortran 2008"   ! First argument (*) means output format and second
                                    ! one the content         
end program hello
