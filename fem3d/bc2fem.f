
	program bc2fem_main

! converts files from win-format to fem-format

	implicit none

	character*50 infile,what,var,hlvfile
	logical bformat
	logical formatted,unformatted
	logical b2d,b3d

	formatted = .true.
	unformatted = .false.
	b2d = .true.
	b3d = .false.

	bformat = .true.
	bformat = .false.

	call parse_command_line(what,var,infile,hlvfile)

	write(6,*) 'what:       ',what
	write(6,*) 'var:        ',var
	write(6,*) 'infile:     ',infile
	write(6,*) 'hlvfile:    ',hlvfile

        if(infile.eq.' ') stop

	if( what .eq. 'meteo' ) then
	  call win2fem(infile,unformatted)
	else if( what .eq. 'reg' ) then
	  call reg2fem(infile,unformatted)
	else if( what .eq. 'bc' ) then
	  if( var .eq. 'zeta' ) then
	    call bc2fem(var,infile,formatted,b2d,hlvfile)
	  else
	    call bc2fem(var,infile,formatted,b3d,hlvfile)
	  end if
	else if( what .eq. 'field' ) then
	  if( var .eq. 'zeta' ) then
	    call field2fem(var,infile,unformatted,b2d,hlvfile)
	  else
	    call field2fem(var,infile,unformatted,b3d,hlvfile)
	  end if
	else
	  write(6,*) 'unknown option: ',what
	end if

	end

c*****************************************************************
c*****************************************************************
c*****************************************************************

	subroutine field2fem(var,infile,bformat,b2d,hlvfile)

	implicit none

	character*(*) var,infile,hlvfile
	logical bformat,b2d

	logical bnew,bpres,bhlv
	integer ios,it,id,n,n0,nvar,nvar0,itanf,nkn,i,j,itend
	integer iunit,nvers,ntype,lmax,np,nlvdim,iformat
	integer irec,ifreq,nlen,l,lmax0
	integer datetime(2)
	real regpar(7)
	double precision dtime
	real, allocatable :: hlv(:)
	real, allocatable :: hd(:)
	integer, allocatable :: ilhkv(:)
	real, allocatable :: data(:,:)
	character*50 string

	bhlv = .true.		!file has hlv information

	iformat = 0
	if( bformat ) iformat = 1

!-------------------------------------------------------------
! open file
!-------------------------------------------------------------

        open(1,file=infile,form='formatted',status='old')

!-------------------------------------------------------------
! read header and see what file it is
!-------------------------------------------------------------

        read(1,*,iostat=ios) it,n,lmax,nvar

        if( ios .ne. 0 ) goto 98
	if( b2d .and. lmax .ne. 1 ) goto 97
	if( nvar .ne. 1 ) goto 94
	
        backspace(1)

	irec = 0
	itanf = it

	write(6,*) 'points:     ',n
	write(6,*) 'lmax:       ',lmax
	write(6,*) 'nvar:       ',nvar

	n0 = n
	lmax0 = lmax
	allocate(data(lmax0,n0))
	allocate(hd(n0))
	allocate(ilhkv(n0))
	allocate(hlv(lmax))
	hd = -999.
	ilhkv = lmax

	call description(var,string)

	if( lmax > 1 .and. .not. bhlv ) then
	  call get_hlv(hlvfile,lmax,hlv)
	end if

	if( bformat ) then
	  open(2,file='out.fem',status='unknown',form='formatted')
	  iformat = 1
	else
	  open(2,file='out.fem',status='unknown',form='unformatted')
	  iformat = 0
	end if

	iunit = 2
	nvers = 0
	ntype = 0
	np = n0
	nlvdim = lmax

!-------------------------------------------------------------
! loop on input and write
!-------------------------------------------------------------

	do
          read(1,*,iostat=ios) it,n,lmax,nvar
	  if( ios .lt. 0 ) exit
	  if( ios .gt. 0 ) goto 98
	  if( b2d .and. lmax .ne. 1 ) goto 97
	  if( nvar .ne. 1 ) goto 94
	  if( n .ne. n0 ) goto 96
	  if( lmax .ne. lmax0 ) goto 96

	  itend = it

	  if( bhlv ) read(1,*) (hlv(l),l=1,lmax)
	  read(1,*) ((data(l,i),l=1,lmax),i=1,n)

	  dtime = it
	  call fem_file_write_header(iformat,iunit,dtime
     +                          ,nvers,np,lmax,nvar,ntype,nlvdim
     +				,hlv,datetime,regpar)
          call fem_file_write_data(iformat,iunit
     +                          ,nvers,np,lmax
     +                          ,string
     +                          ,ilhkv,hd
     +                          ,nlvdim,data)

	  call progress(irec,1,60)
	end do

!-------------------------------------------------------------
! write final message
!-------------------------------------------------------------

	write(6,*) 
	write(6,*) 'total records read: ',irec
	write(6,*) 'start/end time: ',itanf,itend
	write(6,*) 'output has been written to out.fem'

!-------------------------------------------------------------
! end of routine
!-------------------------------------------------------------

	stop
   94	continue
	write(6,*) 'cannot handle nvar different from 1: ',nvar
	stop 'error stop scal2fem'
   95	continue
	write(6,*) 'error in data index: ',i,j
	stop 'error stop scal2fem'
   96	continue
	write(6,*) 'number of points or levels changed: '
	write(6,*) 'n,n0: ',n,n0
	write(6,*) 'lmax,lmax0: ',lmax,lmax0
	stop 'error stop scal2fem'
   97	continue
	write(6,*) 'error in lmax (2d requested): ',lmax
	stop 'error stop scal2fem'
   98	continue
	write(6,*) 'read error: ',ios
	stop 'error stop scal2fem'
	end

c*****************************************************************

	subroutine bc2fem(var,infile,bformat,b2d,hlvfile)

	implicit none

	character*(*) var,infile,hlvfile
	logical bformat,b2d

	logical bnew,bpres
	integer ios,it,id,n,n0,nvar,nvar0,itanf,nkn,i,j,itend
	integer iunit,nvers,ntype,lmax,np,nlvdim,iformat
	integer irec,ifreq,nlen,l,lmax0
	integer datetime(2)
	real regpar(7)
	double precision dtime
	real, allocatable :: hlv(:)
	real, allocatable :: hd(:)
	integer, allocatable :: ilhkv(:)
	real, allocatable :: data(:,:)
	character*50 string

	iformat = 0
	if( bformat ) iformat = 1

!-------------------------------------------------------------
! open file
!-------------------------------------------------------------

        open(1,file=infile,form='formatted',status='old')

!-------------------------------------------------------------
! read header and see what file it is
!-------------------------------------------------------------

        read(1,*,iostat=ios) it,lmax,n,nvar

        if( ios .ne. 0 ) goto 98
	if( b2d .and. lmax .ne. 1 ) goto 97
	if( nvar .ne. 1 ) goto 94
	
        backspace(1)

	irec = 0
	itanf = it

	write(6,*) 'points:     ',n
	write(6,*) 'lmax:       ',lmax
	write(6,*) 'nvar:       ',nvar

	n0 = n
	lmax0 = lmax
	allocate(data(lmax0,n0))
	allocate(hd(n0))
	allocate(ilhkv(n0))
	allocate(hlv(lmax))
	hd = -999.
	ilhkv = lmax

	call description(var,string)

	if( lmax > 1 ) then
	  call get_hlv(hlvfile,lmax,hlv)
	end if

	if( bformat ) then
	  open(2,file='out.fem',status='unknown',form='formatted')
	  iformat = 1
	else
	  open(2,file='out.fem',status='unknown',form='unformatted')
	  iformat = 0
	end if

	iunit = 2
	nvers = 0
	ntype = 0
	np = n0
	nlvdim = lmax

!-------------------------------------------------------------
! loop on input and write
!-------------------------------------------------------------

	do
          read(1,*,iostat=ios) it,lmax,n,nvar
	  if( ios .lt. 0 ) exit
	  if( ios .gt. 0 ) goto 98
	  if( b2d .and. lmax .ne. 1 ) goto 97
	  if( nvar .ne. 1 ) goto 94
	  if( n .ne. n0 ) goto 96
	  if( lmax .ne. lmax0 ) goto 96

	  itend = it

	  do i=1,n
	    read(1,*) j,(data(l,i),l=1,lmax)
	    if( j .ne. i ) goto 95
	  end do

	  dtime = it
	  call fem_file_write_header(iformat,iunit,dtime
     +                          ,nvers,np,lmax,nvar,ntype,nlvdim
     +				,hlv,datetime,regpar)
          call fem_file_write_data(iformat,iunit
     +                          ,nvers,np,lmax
     +                          ,string
     +                          ,ilhkv,hd
     +                          ,nlvdim,data)

	  call progress(irec,24,60)
	end do

!-------------------------------------------------------------
! write final message
!-------------------------------------------------------------

	write(6,*) 
	write(6,*) 'total records read: ',irec
	write(6,*) 'start/end time: ',itanf,itend
	write(6,*) 'output has been written to out.fem'

!-------------------------------------------------------------
! end of routine
!-------------------------------------------------------------

	stop
   94	continue
	write(6,*) 'cannot handle nvar different from 1: ',nvar
	stop 'error stop scal2fem'
   95	continue
	write(6,*) 'error in data index: ',i,j
	stop 'error stop scal2fem'
   96	continue
	write(6,*) 'number of points or levels changed: '
	write(6,*) 'n,n0: ',n,n0
	write(6,*) 'lmax,lmax0: ',lmax,lmax0
	stop 'error stop scal2fem'
   97	continue
	write(6,*) 'error in lmax (2d requested): ',lmax
	stop 'error stop scal2fem'
   98	continue
	write(6,*) 'read error: ',ios
	stop 'error stop scal2fem'
	end

c*****************************************************************

	subroutine reg2fem(infile,bformat)

	implicit none

	character*(*) infile
	logical bformat

	logical bnew,bpres
	integer ios,it,id,n,n0,nvar,nvar0,itanf,nkn,i,j,itend
	integer iunit,nvers,ntype,lmax,np,nlvdim,iformat
	integer irec,ifreq,nlen
	integer nx,ny
	double precision dtime
	integer datetime(2)
	real regpar(7)
	real hlv(1)
	real hd(1)
	integer ilhkv(1)
	character*50 string,newstring
	real, allocatable :: data(:)

	iformat = 0
	if( bformat ) iformat = 1

!-------------------------------------------------------------
! open file
!-------------------------------------------------------------

        open(1,file=infile,form='formatted',status='old')

!-------------------------------------------------------------
! read header and see what file it is
!-------------------------------------------------------------

!-------------------------------------------------------------
! open output file and prepare for writing
!-------------------------------------------------------------

	if( bformat ) then
	  open(2,file='out.fem',status='unknown',form='formatted')
	else
	  open(2,file='out.fem',status='unknown',form='unformatted')
	end if

	irec = 0
	itanf = -1
	itend = 0
	iunit = 2
	nvers = 0
	ntype = 10
	lmax = 1
	nlvdim = 1
	n0 = 0
	nvar0 = 0
	itanf = -1
	ilhkv(1) = 1
	hd(1) = -999.

!-------------------------------------------------------------
! loop on input and write
!-------------------------------------------------------------

	do

	  read(1,*,iostat=ios) it,nvar,(regpar(i),i=1,7)

	  if( ios .lt. 0 ) exit
	  if( ios .gt. 0 ) goto 98

	  irec = irec + 1
	  nx = nint(regpar(1))
	  ny = nint(regpar(2))

	  np = nx * ny
	  if( n0 .eq. 0 ) then
	    n0 = np
	    allocate(data(n0))
	  end if
	  if( nvar0 .eq. 0 ) nvar0 = nvar
	  if( itanf .eq. -1 ) itanf = it

          if( np .ne. n0 ) goto 99
	  if( nvar .ne. nvar0 ) goto 99

	  itend = it

	  dtime = it
	  call fem_file_write_header(iformat,iunit,dtime
     +                          ,nvers,np,lmax,nvar,ntype,nlvdim
     +				,hlv,datetime,regpar)

	  do i=1,nvar
            read(1,'(a)') string
            read(1,*) (data(j),j=1,np)
	    call get_new_string(string,newstring)

            call fem_file_write_data(iformat,iunit
     +                          ,nvers,np,lmax
     +                          ,newstring
     +                          ,ilhkv,hd
     +                          ,nlvdim,data)
	  end do

	  call progress(irec,2,60)
	end do

!-------------------------------------------------------------
! write final message
!-------------------------------------------------------------

	write(6,*) 
	write(6,*) 'total records read: ',irec
	write(6,*) 'start/end time: ',itanf,itend
	write(6,*) 'output has been written to out.fem'

!-------------------------------------------------------------
! end of routine
!-------------------------------------------------------------

	stop
   98	continue
	write(6,*) 'read error: ',ios
	stop 'error stop reg2fem'
   99	continue
	write(6,*) 'parameter mismatch: ',nkn,n0,nvar,nvar0
	stop 'error stop reg2fem'
	end

c*****************************************************************

	subroutine win2fem(infile,bformat)

	implicit none

	character*(*) infile
	logical bformat

	logical bnew,bpres
	integer ios,it,id,n,n0,nvar,nvar0,itanf,nkn,i,j,itend
	integer iunit,nvers,ntype,lmax,np,nlvdim,iformat
	integer irec,ifreq,nlen
	double precision dtime
	real hlv(1)
	real hd(1)
	integer ilhkv(1)
	integer datetime(2)
	real regpar(7)
	real, allocatable :: data(:,:)
	character*50, allocatable :: strings(:)

	iformat = 0
	if( bformat ) iformat = 1

!-------------------------------------------------------------
! open file
!-------------------------------------------------------------

        open(1,file=infile,form='unformatted',status='old')

!-------------------------------------------------------------
! read header and see what file it is
!-------------------------------------------------------------

        bnew = .false.
        read(1,iostat=ios) it,id,n,nvar
        if( ios .eq. 0 ) then
	  if( id .ge. 1001 .and. id .le. 1003 ) then
	    bnew = .true.
	  else
	    write(6,*) 'cannot read file format...'
	    stop 'error stop win2fem'
	  end if
	else
	  id = 0
	end if
        backspace(1)

	if( .not. bnew ) then
          read(1,iostat=ios) it,n
          if( ios .ne. 0 ) then
	    write(6,*) 'cannot read file format...'
	    stop 'error stop win2fem'
	  end if
	  nvar = 3
	  id = 1001
          backspace(1)
	end if

!-------------------------------------------------------------
! set parameters and allocate space
!-------------------------------------------------------------

	irec = 0
	itanf = it
	n0 = abs(n)
	nvar0 = nvar
	bpres = bnew .or. n < 0

	!write(6,*) id,itanf,n0,nvar,bnew
	write(6,*) 'file id:    ',id
	write(6,*) 'points:     ',n0
	write(6,*) 'nvar:       ',nvar
	write(6,*) 'new format: ',bnew
	if( id .eq. 1001 ) then
	  write(6,*) 'pressure  : ',bpres
	end if

	allocate(data(n0,nvar))
	allocate(strings(nvar))
	if( id .eq. 1001 ) data(:,3) = 1013.25
	if( id .eq. 1001 ) then
          strings(1) = 'wind velocity in x [m/s]'
          strings(2) = 'wind velocity in y [m/s]'
          strings(3) = 'pressure (atmospheric) [Pa]'
	else if( id .eq. 1002 ) then
	  strings(1) = 'solar radiation [W/m**2]'
          strings(2) = 'air temperature [C]'
          strings(3) = 'humidity [%]'
          strings(4) = 'cloud cover [0-1]'
	else if( id .eq. 1003 ) then
	  strings(1) = 'rain [mm/day]'
	else
	  write(6,*) 'id: ',id
	  stop 'error stop: id'
	end if

	write(6,*) 'content: '
	do i=1,nvar
	  write(6,*) '   ',strings(i)
	end do
	write(6,*) 'working...'

!-------------------------------------------------------------
! open output file and prepare for writing
!-------------------------------------------------------------

	if( bformat ) then
	  open(2,file='out.fem',status='unknown',form='formatted')
	else
	  open(2,file='out.fem',status='unknown',form='unformatted')
	end if

	iunit = 2
	nvers = 0
	ntype = 0
	lmax = 1
	np = n0
	nlvdim = 1

!-------------------------------------------------------------
! loop on input and write
!-------------------------------------------------------------

	do

          if( bnew ) then
            read(1,iostat=ios) it,id,n,nvar
	    nkn = n
          else
            read(1,iostat=ios) it,nkn
	    nvar = 3
          end if
	  if( ios .lt. 0 ) exit
	  if( ios .gt. 0 ) goto 98
          bpres = .false.
          if( nkn .lt. 0 ) then
            nkn = -nkn
            bpres = .true.
          end if

          if( nkn .ne. n0 ) goto 99
	  if( nvar .ne. nvar0 ) goto 99

	  itend = it

          if( bnew ) then
            !read(1) (data(i,1),data(i,2),data(i,3),i=1,nkn)
            read(1) ((data(i,j),j=1,nvar),i=1,nkn)
          else if( bpres ) then
            read(1) (data(i,1),data(i,2),i=1,nkn),(data(i,3),i=1,nkn)
          else
            read(1) (data(i,1),data(i,2),i=1,nkn)
	    do i=1,nkn
	      data(i,3) = 1013.25
	    end do
          end if

	  dtime = it
	  call fem_file_write_header(iformat,iunit,dtime
     +                          ,nvers,np,lmax,nvar,ntype,nlvdim
     +				,hlv,datetime,regpar)
	  do i=1,nvar
            call fem_file_write_data(iformat,iunit
     +                          ,nvers,np,lmax
     +                          ,strings(i)
     +                          ,ilhkv,hd
     +                          ,nlvdim,data(1,i))
	  end do

	  call progress(irec,2,60)
	end do

!-------------------------------------------------------------
! write final message
!-------------------------------------------------------------

	write(6,*) 
	write(6,*) 'total records read: ',irec
	write(6,*) 'start/end time: ',itanf,itend
	write(6,*) 'output has been written to out.fem'

!-------------------------------------------------------------
! end of routine
!-------------------------------------------------------------

	stop
   98	continue
	write(6,*) 'read error: ',ios
	stop 'error stop win2fem'
   99	continue
	write(6,*) 'parameter mismatch: ',nkn,n0,nvar,nvar0
	stop 'error stop win2fem'
	end

c*****************************************************************

	subroutine get_new_string(string,newstring)

	implicit none

	character*(*) string,newstring

	string = adjustl(string)

	if( string .eq. 'wind wx' ) then
	  newstring = 'wind velocity in x [m/s]'
	else if( string .eq. 'wind wy' ) then
          newstring = 'wind velocity in y [m/s]'
	else if( string .eq. 'atmospheric pressure' ) then
          newstring = 'pressure (atmospheric) [Pa]'
	else if( string .eq. 'rain' ) then
	  newstring = 'rain [mm/day]'
	else if( string .eq. 'solar radiation' ) then
	  newstring = 'solar radiation [W/m**2]'
	else if( string .eq. 'air temperature' ) then
          newstring = 'air temperature [C]'
	else if( string .eq. 'relative humidity' ) then
          newstring = 'humidity [%]'
	else if( string .eq. 'cloud cover' ) then
          newstring = 'cloud cover [0-1]'
	else
	  write(6,*) 'unknown string: '
	  write(6,*) string
	  stop 'error stop get_new_string: unknown string'
	end if

	end

c*****************************************************************
c*****************************************************************
c*****************************************************************

	subroutine parse_command_line(what,var,infile,hlv)

	implicit none

	character*(*) what,var,infile,hlv

	integer i,nc
	character*50 aux

	what = ' '
	var = ' '
	infile = ' '
	hlv = ' '

	nc = command_argument_count()

	if( nc >= 2 ) then
	  call get_command_argument(1,aux)
	  what = aux(2:)

	  i = 1
	  do
	    i = i + 1
	    if( i >= nc ) exit
	    call get_command_argument(i,aux)
	    if( aux .eq. '-hlv' ) then
	      i = i + 1
	      call get_command_argument(i,hlv)
	    else if( aux .eq. '-zeta' ) then
	      var = aux(2:)
	    else if( aux .eq. '-temp' ) then
	      var = aux(2:)
	    else if( aux .eq. '-salt' ) then
	      var = aux(2:)
	    else if( aux .eq. '-conz' ) then
	      var = aux(2:)
	    else if( aux .eq. '-scal' ) then
	      var = aux(2:)
	    else
	      write(6,*) 'unknown option: ',aux
	      exit
	    end if
	  end do
	  call get_command_argument(nc,infile)
	  if( i .eq. nc ) return
	end if

	write(6,*) 'Usage: win2fem [-what] [-var] [options] bc-file'
	write(6,*) '   what:'
	write(6,*) '      -meteo      2d unformatted meteo files'
	write(6,*) '      -reg        2d regular meteo files'
	write(6,*) '      -bc         boundary condition file'
	write(6,*) '      -field      2d/3d scalar field'
	write(6,*) '   var:'
	write(6,*) '      -zeta       water level'
	write(6,*) '      -temp       temperature'
	write(6,*) '      -salt       salinity'
	write(6,*) '      -conz       generic tracer'
	write(6,*) '      -scal       generic scalar file'
	write(6,*) '   options:'
	write(6,*) '      -hlv file   file containing hlv levels'

	stop
	end

c*****************************************************************

	subroutine progress(irec,ifreq,nlen)

	implicit none

	integer irec,ifreq,nlen

	irec = irec + 1
	if( mod(irec,ifreq) .eq. 0 ) write(6,'(a1)',advance='no') '.'
	if( mod(irec,ifreq*nlen) .eq. 0 ) write(*,*)	!new line

	end

c*****************************************************************

	subroutine description(what,string)

	implicit none

	character*50 what,string

	if( what .eq. 'zeta' ) then
	  string = 'water level [m]'
	else if( what .eq. 'temp' ) then
	  string = 'temperature [C]'
	else if( what .eq. 'salt' ) then
	  string = 'salinity [psu]'
	else if( what .eq. 'conz' ) then
	  string = 'generic tracer'
	else
	  string = ' '
	end if

	if( string .ne. ' ' ) return

	write(6,*) 'for scalar files we need a description'
	write(6,*) 'please insert a description:'

	read(5,'(a)') string

	end

c*****************************************************************

	subroutine get_hlv(hlvfile,lmax,hlv)

	implicit none

	character*(*) hlvfile
	integer lmax
	real hlv(lmax)

	integer l
	character*50 file

	write(6,*) 'for 3D files we need vertical structure of levels'
	write(6,*) 'the file must contain hlv values, lmax = ',lmax

	if( hlvfile .eq. ' ' ) then
	  write(6,*) 'Enter file name: '
	  read(5,'(a)') file
	else
	  file = hlvfile
	end if
	write(6,*) 'opening file: ',file

	open(3,file=file,status='old',form='formatted')
	read(3,*) (hlv(l),l=1,lmax)
	close(3)

	write(6,*) 'The following levels have been read: ',lmax
	do l=1,lmax
	  write(6,*) l,hlv(l)
	end do

	end

c*****************************************************************
