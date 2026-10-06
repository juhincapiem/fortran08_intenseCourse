# Leveraging profiling tools
The purpose of this document is to give to the reader some basic guidelines that may help to understand either loop profiling and trace profiling.

## Loop propfiling
- Run `sbatch jobRelease_loopProfiling.slurm`
- Uncomment the following line inside the MPICRAY function within the PFemuss.inc file:
```
  loops = -h profile_generate     # Loops profiling for cray compiler. Just for profiling in CPU version
```
- The results are written inside the file called `loop_profiling_CG_CPU`

## Header: checking what we measure
So, before reading any table, it is worthy having a look at the current context:

- Number of PEs: 1, Threads per PE: 1: one MPI rank, one thread. A single CPU core.
- Original program: ...PFemuss.OMPICRAY: the CPU build.
- Accelerator Model: AMD MI200: the run happened on a GPU node (standard-g), even though the GPUs weren't used. 

## Table 1: nested loops
How to read a line: `apply_a$temgpu_solite_.LOOP.2.li.222` means "a loop inside the subroutine apply_a, which lives inside the file tempgpu_solite, starting at line 222". 

The number at the far left is the nesting depth. The columns:
- **Incl Time%:** time of this loop including evverything inside it.
- **Loop Exec:** how many times the loop was entered.
- **Loop Trips Avg:** iterations per entry.

**WHERE TO LOOK?!** keep an eye on those loops where the percentage stays high. Everything at 0.0 % is input parsing and setup: you can ignore it. 

```
temgpu_solite LOOP.1  li.74   84.8%  exec 1     trips 1,000   <- CG loop (do k = 1, maxit)
 apply_a     LOOP.2  li.222  84.8%  exec 132   trips 12,800  <- element loop (do ielem)

  apply_a    LOOP.3  li.228  84.5%  1,689,600   trips 3       <- Gauss points (do igaus)

   apply_a   LOOP.4  li.232  13.6%  5,068,800   trips 3       <- Jacobian

   apply_a   LOOP.7  li.284  69.2%  15,206,400  trips 3       <- do inode (assembly)

    apply_a  LOOP.8  li.289  10.7%              trips 2       <- gradI
    apply_a  LOOP.10 li.295  53.5%              trips 3       <- do jnode
     apply_a LOOP.11 li.300  32.1%              trips 2       <- gradJ
     apply_a LOOP.13 li.307   6.4%              trips 2       <- k_ij dot product
 apply_a     LOOP.14 li.333   0.0%  exec 132   trips 6,561   <- Dirichlet loop
 apply_a     LOOP.1  li.205   0.0%  exec 132   trips 6,561   <- zeroing y
```

What it means:
- The **CG loop** shows 1,000 loops, but 132 were actually executed. It appears that the profiling tool recorded the maximum possible number of iterations, and did not detect the early exit of the loop. 
- In the **element loop** line, the trip is describing the amount of elements that composed the mesh: 12,800 elements. That amount of iteratons for the whole mesh.
    - Then we have the number of **Gaussian points**: 3. So, if we have 12,800 elements, and the program took over 132 iterations, then the solver will entered to this nested loop 1,689,600 times. This is different from the total Gauss-point iteratinos, that would be 12,800 x 132 x 3.
    - The same trip analysis can be done to the following nested loops, for instance the **Jacobian** one.
- Following the path, we may see that the most amount of time is dedicated to the **assembly** loop (69.2 %), 
    - and more than half of it in the **jnode** loop (53.5%).
    - and inside that, **gradJ** alone takes 32%. 
- The **zeroing** and **Dirichlet** loops are 0.0%. Confirmed negligible.


## Table 2: functions and regions by exclusive time

```
#2.Second Loop   85.4%   6.318 s   133 calls
```

 The others pat regions weren't included in the table becauce they all have insignificants execution times. 

## Table 3: load balance
With one rank there's nothing to balance. It will become important when we run with several MPI ranks: it shows whether some rank is doing more work than the others.

## Table 4: MPI messages
which MPI calls send data, how much, in how many messages, and from where in the code. Column by column:

- **MPI Msg Bytes:** total bytes sent by that MPI function (and, below it, by each caller).
- **MPI Msg Count:** number of messages.
- **MsgSz <16 / 16<= <256 / 256<= <4KiB:** how many messages fall into each size range. It tells you whether the communication is many tiny messages (dominated by latency) or few large ones (dominated by bandwidth).
- **Caller:** the call path that leads to the MPI call, read from top to bottom, from the MPI function up to main.

The important line:

```
MPI_ALLREDUCE   264 calls   <- mpidotallreduce_, from temgpu_solite_.LOOP.1.li.74
```

## Table 5: energy

```
Node   531 W   3,946 J
CPU     47 W     347 J
Acc0-3 ~90-98 W each  ~2,780 J total
```

The four GPUs consumed about 70% of the node's energy while doing nothing

## Tables 6 and 7: memory and wall time
- 144.7 MiB maximum memory. Small; the mesh is small.
- 7.43 s wall time, again inflated by the instrumentation.
