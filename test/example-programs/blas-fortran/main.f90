program blas_test_fortran
  implicit none
  integer :: N, K, repeats, M
  integer :: i, szA, szB, szC
  real, allocatable :: A(:), B(:), C(:)
  real :: alpha, beta
  real :: t0, t1, secs, csum
  character(len=16) :: arg
  external sgemm

  ! Defaults
  N = 2048
  K = 2048
  repeats = 50

  if (command_argument_count() >= 1) then
    call get_command_argument(1, arg)
    read(arg, *) N
  end if
  if (command_argument_count() >= 2) then
    call get_command_argument(2, arg)
    read(arg, *) K
  end if
  if (command_argument_count() >= 3) then
    call get_command_argument(3, arg)
    read(arg, *) repeats
  end if

  if (N <= 0 .or. K <= 0 .or. repeats <= 0) then
    write(0, '(A)') 'Usage: blas-test [N] [K] [repeats]'
    stop 1
  end if

  M = N

  szA = M*K
  szB = K*N
  szC = M*N

  allocate(A(szA))
  allocate(B(szB))
  allocate(C(szC))

  call init_matrix(A, M, K, 1)
  call init_matrix(B, K, N, 2)
  C = 0.0

  alpha = 1.0
  beta  = 0.0

  ! Warmup
  call sgemm('N','N', M, N, K, alpha, A, M, B, K, beta, C, M)

  call wall_time(t0)
  do i = 1, repeats
    call sgemm('N','N', M, N, K, alpha, A, M, B, K, beta, C, M)
  end do
  call wall_time(t1)

  secs = t1 - t0
  csum = checksum(C)

  call print_json('BLAS', M, N, K, repeats, '', secs, csum)

contains

  subroutine wall_time(t)
    real, intent(out) :: t
    integer :: count, rate
    call system_clock(count, rate)
    if (rate > 0) then
      t = real(count) / real(rate)
    else
      call cpu_time(t)
    end if
  end subroutine wall_time

  subroutine init_matrix(Ma, rows, cols, seed)
    real, intent(out) :: Ma(:)
    integer, intent(in) :: rows, cols, seed
    integer :: i
    integer :: x
    x = merge(seed, 1, seed /= 0)
    do i = 1, rows*cols
      x = modulo(1664525*x + 1013904223, huge(1))
      Ma(i) = real(ibits(x, 8, 16)) / 32768.0 - 1.0
    end do
  end subroutine init_matrix

  real function checksum(Ma)
    real, intent(in) :: Ma(:)
    integer :: i
    real :: s
    s = 0.0
    do i = 1, size(Ma)
      s = s + Ma(i)
    end do
    checksum = s
  end function checksum

  subroutine print_json(engine_name, M, N, K, repeats, error, secs, csum)
    character(len=*), intent(in) :: engine_name
    integer, intent(in) :: M, N, K, repeats
    character(len=*), intent(in) :: error
    real, intent(in) :: secs, csum
    integer(kind=8) :: szA, szB, szC, total_bytes
    real :: total_mb, gflops

    szA = int(M,8)*int(K,8)*int(storage_size(0.0)/8,8)
    szB = int(K,8)*int(N,8)*int(storage_size(0.0)/8,8)
    szC = int(M,8)*int(N,8)*int(storage_size(0.0)/8,8)
    total_bytes = szA + szB + szC
    total_mb = real(total_bytes) / (1024.0*1024.0)

    if (secs > 0.0) then
      gflops = (2.0*real(M)*real(N)*real(K)*real(repeats)) / (secs*1.0e9)
    else
      gflops = 0.0
    end if

    write(*,'(A)') '{'
    write(*,'(A,A,A)') '  "engine": {"name":"', trim(engine_name), '"},'
    write(*,'(A)') '  "input": {'
    write(*,'(A,I0,A)') '    "M": ', M, ','
    write(*,'(A,I0,A)') '    "N": ', N, ','
    write(*,'(A,I0,A)') '    "K": ', K, ','
    write(*,'(A,I0,A)') '    "repeats": ', repeats, ','
    write(*,'(A,I0,A)') '    "expected_bytes_total": ', total_bytes, ','
    write(*,'(A,F12.1)') '    "expected_megabytes_total": ', total_mb
    write(*,'(A)') '  },'
    if (len_trim(error) > 0) then
      write(*,'(A,A,A)') '  "error": "', trim(error), '"'
    end if
    if (secs > 0.0) then
      write(*,'(A)') '  "output": {'
      write(*,'(A,F12.6,A)') '    "time_sec": ', secs, ','
      write(*,'(A,F12.2,A)') '    "gflops": ', gflops, ','
      write(*,'(A,F24.6)') '    "checksum": ', csum
      write(*,'(A)') '  }'
    end if
    write(*,'(A)') '}'
  end subroutine print_json



end program blas_test_fortran
