! buildinfo.F90 - Fortran program that prints compiler/target info as JSON
! Uses C preprocessor (-cpp) to detect GCC feature macros

#define STR_HELPER(x) #x
#define STR(x) STR_HELPER(x)

program buildinfo
  implicit none

  call print_json()
contains

  subroutine print_sep(first)
    logical, intent(inout) :: first
    if (first) then
      first = .false.
    else
      write(*,'(A)') ','
    end if
  end subroutine print_sep

  subroutine print_kv_str(first, key, val)
    logical, intent(inout) :: first
    character(len=*), intent(in) :: key
    character(len=*), intent(in) :: val
    call print_sep(first)
    call print_json_string(key)
    write(*,'(A)',advance='no') ': '
    call print_json_string(val)
  end subroutine print_kv_str

  subroutine print_kv_bool(first, key, val)
    logical, intent(inout) :: first
    character(len=*), intent(in) :: key
    logical, intent(in) :: val
    call print_sep(first)
    call print_json_string(key)
    write(*,'(A)',advance='no') ': '
    if (val) then
      write(*,'(A)',advance='no') 'true'
    else
      write(*,'(A)',advance='no') 'false'
    end if
  end subroutine print_kv_bool

  subroutine print_json_string(s)
    character(len=*), intent(in) :: s
    integer :: i, n
    character(len=1) :: c
    write(*,'(A)',advance='no') '"'
    n = len_trim(s)
    do i = 1, n
      c = s(i:i)
      select case (c)
      case ('"')
        write(*,'(A)',advance='no') '\"'
      case ('\\')
        write(*,'(A)',advance='no') '\\'
      case default
        write(*,'(A)',advance='no') c
      end select
    end do
    write(*,'(A)',advance='no') '"'
  end subroutine print_json_string

  subroutine print_json()
    logical :: first
    ! Start JSON
    write(*,'(A)') '{'

    ! Compiler block
    write(*,'(A)') '"compiler": {'
    ! Manage commas between fields
    first = .true.

#ifdef __VERSION__
    call print_kv_str(first, 'version_string', __VERSION__)
#else
    call print_kv_str(first, 'version_string', 'unknown')
#endif

#ifdef __FAST_MATH__
    call print_kv_bool(first, 'fast_math', .true.)
#else
    call print_kv_bool(first, 'fast_math', .false.)
#endif

#ifdef __SSE__
    call print_kv_bool(first, 'sse', .true.)
#endif
#ifdef __SSE2__
    call print_kv_bool(first, 'sse2', .true.)
#endif
#ifdef __SSE3__
    call print_kv_bool(first, 'sse3', .true.)
#endif
#ifdef __SSSE3__
    call print_kv_bool(first, 'ssse3', .true.)
#endif
#ifdef __SSE4_1__
    call print_kv_bool(first, 'sse4_1', .true.)
#endif
#ifdef __SSE4_2__
    call print_kv_bool(first, 'sse4_2', .true.)
#endif
#ifdef __AVX__
    call print_kv_bool(first, 'avx', .true.)
#endif
#ifdef __AVX2__
    call print_kv_bool(first, 'avx2', .true.)
#endif

#ifdef __AVX512F__
    call print_kv_bool(first, 'avx512f', .true.)
#endif
#ifdef __AVX512CD__
    call print_kv_bool(first, 'avx512cd', .true.)
#endif
#ifdef __AVX512ER__
    call print_kv_bool(first, 'avx512er', .true.)
#endif
#ifdef __AVX512PF__
    call print_kv_bool(first, 'avx512pf', .true.)
#endif
#ifdef __AVX512BW__
    call print_kv_bool(first, 'avx512bw', .true.)
#endif
#ifdef __AVX512DQ__
    call print_kv_bool(first, 'avx512dq', .true.)
#endif
#ifdef __AVX512VL__
    call print_kv_bool(first, 'avx512vl', .true.)
#endif
#ifdef __AVX512IFMA__
    call print_kv_bool(first, 'avx512ifma', .true.)
#endif
#ifdef __AVX512VBMI__
    call print_kv_bool(first, 'avx512vbmi', .true.)
#endif
#ifdef __AVX512VNNI__
    call print_kv_bool(first, 'avx512vnni', .true.)
#endif

    write(*,'(A)') '},'

    ! Target block
    write(*,'(A)') '"target": {'
    first = .true.
#ifdef __x86_64__
    call print_kv_str(first, 'arch', 'x86_64')
#elif defined(__aarch64__)
    call print_kv_str(first, 'arch', 'aarch64')
#else
    call print_kv_str(first, 'arch', 'unknown')
#endif
    write(*,'(A)') '}'

    write(*,'(A)') '}'
  end subroutine print_json

end program buildinfo
