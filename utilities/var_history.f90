program history_check
use iso_c_binding, only: C_INT, C_DOUBLE, C_DOUBLE_COMPLEX, C_SIZE_T
implicit none

! stuff for dns.in
integer(C_INT) :: nx, ny, nz, intemp
real(C_DOUBLE) :: temp ! alfa0, beta0, ni, a, ymin, ymax, deltat, cflmax, time, dt_field, dt_save, t_max, gamma, u0, uN, meanpx, meanpz, meanflowx, meanflowz
character(len=32) :: cmd_in_buf
! velocity field, average
complex(C_DOUBLE_COMPLEX), allocatable :: vel(:,:,:,:) ! iy, iz, ix, ic
real(C_DOUBLE), allocatable :: average(:,:), var(:,:), instantaneous(:,:), instant_history(:,:,:), var_history(:,:,:), factor
! counters and flags
integer :: ifld, ix, iy, iz, ic, fstart, fend, noflds
logical :: ex

    ! first off: read dns.in
    call read_dnsin()

    ! fetch number of fields
    call get_command_argument(1, cmd_in_buf)
    read(cmd_in_buf, *) fstart
    call get_command_argument(2, cmd_in_buf)
    read(cmd_in_buf, *) fend
    noflds = fend - fstart + 1 ! calculate total number of fields

    ! allocate fields
    allocate(vel(-1:ny+1,-nz:nz,0:nx,1:3))
    allocate(average(0:ny,1:3)); average = 0
    allocate(var(0:ny,1:3));     var = 0
    allocate(instantaneous(0:ny,1:3))
    allocate(instant_history(0:ny,1:3,fstart:fend))
    allocate(var_history(0:ny,1:3,fstart:fend))

    ! calculate average
    print *, "Calculating average..."
    do ifld = fstart, fend
        open(unit=777, file="Dati.cart."//itoa(ifld)//".out", access="stream", status="old", action="read")
        do ic = 1,3
            do iy = 0,ny
                average(iy,ic) = average(iy,ic) + real(fieldmap(777,iy,0,0,ic))/noflds
            end do
        end do
        close(777)
    end do

    ! write average to file
    !open(778, file="average.txt", status="unknown")
    !    do iy = 0,ny
    !        write(778,*) average(iy,1), average(iy,2), average(iy,3)
    !    end do
    !close(778)

    ! calculate variances
    do ifld = fstart, fend
        ! read file
        write(*,"(a,$)") " Reading file "//itoa(ifld)//" out of "//itoa(fend)
        call read_file("Dati.cart."//itoa(ifld)//".out", vel)
        write(*,"(a)") " - calculating instantaneous variance"
        ! sum everything
        instantaneous = 0 ! empty instantaneous to begin with
        do ic = 1,3
            do ix = 0,nx
                if (ix == 0) then
                    factor = 1
                else
                    factor = 2
                endif
                do iz = -nz,nz
                    do iy = 0,ny
                        instantaneous(iy,ic) = instantaneous(iy,ic) + factor * abs(vel(iy,iz,ix,ic))**2
                    end do
                end do
            end do
        end do
        instantaneous(:,:) = instantaneous(:,:) - average(:,:)**2
        ! store instantaneous
        instant_history(:,:,ifld) = instantaneous(:,:)           
        ! then sum instantaneous to cumulative
        var = var + instantaneous
        ! then store cumulative/ifld
        var_history(:,:,ifld) = var(:,:) / (ifld-fstart+1) 
    end do

    ! dump to disk
    inquire(directory="var_history", exist=ex)
    if (.not. ex) then
        call system("mkdir var_history")
    end if
    open(unit=778, file="var_history/instantaneous.bin", access="stream", action="write", status='replace')
        write(778, pos=1) instant_history
    close(778)
    open(unit=779, file="var_history/cumulative.bin", access="stream", action="write", status='replace')
        write(779, pos=1) var_history
    close(779)

contains



    subroutine read_file(filename, R)

        complex(C_DOUBLE_COMPLEX), intent(INOUT) :: R(-1:(ny+1),-nz:nz,0:nx,1:3)
        character(*), intent(IN) :: filename
        integer :: base = 3*C_INT + 7*C_DOUBLE + 1

        open(unit=100, file=filename, access="stream", status="old", action="read")
            !read(100,pos=1) intemp, intemp, intemp, temp, temp, temp, temp, temp, temp, temp, R
            read(100,pos=base) R
        close(100)

    end subroutine read_file



    subroutine read_dnsin()
            open(15, file='dns.in')
            read(15, *) nx, ny, nz;
            close(15)
    end subroutine read_dnsin



    function itoa(i) result(res)
        character(:),allocatable :: res
        integer,intent(in) :: i
        character(range(i)+2) :: tmp
        
        write(tmp,'(i0)') i
        res = trim(tmp)
    end function



    function fieldmap(unit, iy_zero, iz_zero, ix_zero, ic_zero) result(element)
        integer, intent(in) :: unit, ix_zero, iy_zero, iz_zero, ic_zero
        integer(C_SIZE_T) :: ix, iy, iz, ic
        complex(C_DOUBLE_COMPLEX) :: element
        integer(C_SIZE_T) :: position, el_idx ! position
        integer :: base = 3*C_INT + 7*C_DOUBLE ! base address
        
        ! calculate indices starting from 1
        ix = ix_zero + 1
        iz = iz_zero + nz + 1
        iy = iy_zero + 2
        ic = ic_zero

        ! calculate position
        el_idx = (ic-1_C_SIZE_T)*(nx+1_C_SIZE_T)*(2_C_SIZE_T*nz+1_C_SIZE_T)*(ny+3_C_SIZE_T) + (ix-1_C_SIZE_T)*(2_C_SIZE_T*nz+1_C_SIZE_T)*(ny+3_C_SIZE_T) + (iz-1_C_SIZE_T)*(ny+3_C_SIZE_T) + iy
        position = base + 1_C_SIZE_T + (el_idx - 1) * SIZEOF(element)

        ! read element
        read(unit,pos=position) element

    end function



end program