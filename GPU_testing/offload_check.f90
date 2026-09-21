program offload_check
    use omp_lib
    implicit none

    logical :: on_host

    print *, "Devices visible to OpenMP: ", omp_get_num_devices()

    on_host = .true.
    !$omp target map(from: on_host)
    on_host = omp_is_initial_device()
    !$omp end target

    if (on_host) then
        print *, "Ran on the CPU  -- offload did NOT happen"
    else
        print *, "Ran on the GPU  -- offload works"
    end if
end program offload_check
