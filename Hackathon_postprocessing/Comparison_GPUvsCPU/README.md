# Timing results: matrix-free CG, CPU vs GPU

## Timing fields

| Field | What it measures |
|---|---|
| `t_init` | GPU only: data region entry (mesh upload, device initialization) + first kernel (code loading). 0 on CPU. |
| `t_rhs` | `compute_B` (right-hand side assembly) |
| `t_cgsetup` | Initial `Apply_A`, `r = b - Ap`, `p = r` and the first dot product |
| `t_cg` | The whole CG loop |
| `t_cg_per_iter` | `t_cg` / number of iterations |
| `t_applyA_per_call` | Mean time of one `Apply_A` call inside the CG loop |
| `t_exit` | GPU only: data region exit (copy of `u` back to the host). 0 on CPU. |
| `t_total` | The whole `temgpu_solite` routine |

## Timer placement: CPU version

```fortran
subroutine temgpu_solite(a)
    ...
    t0 = wtime()                                ! t_total starts
    ...
    t1 = wtime()                                ! t_rhs starts
    call compute_B(b)
    t2 = wtime()                                ! t_rhs ends, t_cgsetup starts

    call Apply_A(u, Ap)
    r = b - Ap
    p = r
    call MPIdotAllReduce(r, r, n, rdot, a%MPIcomm)
    t3 = wtime()                                ! t_cgsetup ends, t_cg starts

    do k = 1, maxit
        ta = wtime()                            ! Apply_A starts
        call Apply_A(p, Ap)
        t_apply = t_apply + (wtime() - ta)      ! Apply_A ends (accumulated)
        ...
    end do
    t4 = wtime()                                ! t_cg ends

    a%unkno(1,1:npoinLocal) = u
    t_total = wtime() - t0                      ! t_total ends
    ...
end subroutine temgpu_solite
```

## Timer placement: GPU version

```fortran
subroutine temgpu_solite(a)
    ...
    t0 = wtime()                                ! t_total starts
    ...
    tA = wtime()                                ! t_init starts
    !$omp target data map(...)

    !$omp target teams distribute parallel do   ! first kernel: u = 0
    do i = 1, n
        ...
    end do
    !$omp end target teams distribute parallel do
    t1 = wtime()                                ! t_init ends, t_rhs starts

    call compute_B(b)
    t2 = wtime()                                ! t_rhs ends, t_cgsetup starts

    call Apply_A(u, Ap)
    ...                                         ! r = b - Ap, p = r (kernels)
    call gpu_dot(r, r, n, rdot)
    t3 = wtime()                                ! t_cgsetup ends, t_cg starts

    do k = 1, maxit
        ta = wtime()                            ! Apply_A starts
        call Apply_A(p, Ap)
        t_apply = t_apply + (wtime() - ta)      ! Apply_A ends (accumulated)
        ...
    end do
    t4 = wtime()                                ! t_cg ends, t_exit starts

    !$omp end target data
    t5 = wtime()                                ! t_exit ends

    a%unkno(1,1:npoinLocal) = u
    t_total = wtime() - t0                      ! t_total ends
    ...
end subroutine temgpu_solite
```

## CPU vs GPU

| | CPU | GPU | Speedup |
|---|---|---|---|
| Hardware | 1 CPU core | 1 GCD (MI250X) | — |
| Elements | 51,200 | 51,200 | — |
| Iterations | 261 | 261 | — |
| Final residual | 8.83116285927485E-09 | 8.83116285927371E-09 | — |
| `t_total` (s) | 8.28441 | 0.414753 | 20.0× |
| `t_init` (s) | 0 | 0.318123 | — |
| `t_rhs` (s) | 0.0134386 | 0.000450684 | 29.8× |
| `t_cgsetup` (s) | 0.0318542 | 0.00554210 | 5.7× |
| `t_cg` (s) | 8.23910 | 0.0905602 | 91.0× |
| `t_cg_per_iter` (s) | 0.0315674 | 0.000346974 | 91.0× |
| `t_applyA_per_call` (s) | 0.0315440 | 0.000181132 | 174.1× |
| `t_exit` (s) | 0 | 0.0000563690 | — |