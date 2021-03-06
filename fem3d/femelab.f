!
! elaborates fem files
!
! revision log :
!
! 14.01.2015    ggu     adapted from feminf
! 20.05.2015    ggu     use bhuman to convert to human readable time
! 05.06.2015    ggu     iextract to extract nodal value
! 05.11.2015    ggu     new option chform to change format
!
!******************************************************************

	program femelab

c writes info on fem file

	use clo

	implicit none

	character*80 name,string,infile
	integer nfile
	double precision tmin,tmax
	character*80 stmin,stmax
	logical bdebug,bskip,bwrite,bout,btmin,btmax,bquiet
	logical bchform,bcheckdt

	bdebug = .true.
	bdebug = .false.

c--------------------------------------------------------------
c set command line options
c--------------------------------------------------------------

	call clo_init('femelab','fem-file','1.2')

	call clo_add_info('elaborates and rewrites a fem file')

        call clo_add_sep('what to do (only one of these may be given)')

	call clo_add_option('out',.false.,'create output file out.fem')
        call clo_add_option('node node',-1,'extract value for node')
	call clo_add_option('split',.false.,'splits to single variables')

        call clo_add_sep('options in/output')

	call clo_add_option('write',.false.,'write min/max of values')
	call clo_add_option('quiet',.false.,'do not be verbose')

	call clo_add_sep('additional options')

	call clo_add_option('chform',.false.,'change output format')
        call clo_add_option('checkdt',.false.
     +                          ,'check for change of time step')
	call clo_add_option('tmin time',' '
     +				,'only process starting from time')
	call clo_add_option('tmax time',' '
     +				,'only process up to time')

	call clo_add_sep('additional information')

	call clo_add_extra('format for time is YYYY-MM-DD[::hh:mm:ss]')
	call clo_add_extra('time may be integer for relative time')
	call clo_add_extra('node is internal numbering in fem file')

c--------------------------------------------------------------
c parse command line options
c--------------------------------------------------------------

	call clo_parse_options(1)  !expecting (at least) 1 file after options

c--------------------------------------------------------------
c get command line options
c--------------------------------------------------------------

	call clo_get_option('write',bwrite)
	call clo_get_option('out',bout)
	call clo_get_option('chform',bchform)
	call clo_get_option('quiet',bquiet)
        call clo_get_option('checkdt',bcheckdt)
	call clo_get_option('tmin',stmin)
	call clo_get_option('tmax',stmax)

c--------------------------------------------------------------
c set parameters
c--------------------------------------------------------------

	bskip = .not. bwrite
	if( bout ) bskip = .false.
	btmin = tmin .ne. -1.
	btmax = tmax .ne. -1.

	nfile = clo_number_of_files()

	if( bdebug ) then
	  write(6,*) nfile
	  write(6,*) bwrite,bskip,bout,btmin,btmax
	  write(6,*) tmin,tmax
	end if

c--------------------------------------------------------------
c loop on files
c--------------------------------------------------------------

	if( nfile > 1 ) then
	  write(6,*) 'Can only handle one file at a time'
	  stop 'error stop femelab: too many files'
	end if

        call clo_get_file(1,infile)
        if( infile .ne. ' ' ) call femelab_file(infile)

c--------------------------------------------------------------
c end of routine
c--------------------------------------------------------------

        end

c*****************************************************************
c*****************************************************************
c*****************************************************************

	subroutine femelab_file(infile)

c writes info on fem file

	use clo

	implicit none

	character*(*) infile

	character*80 name,string
	integer np,iunit,iout
	integer nvers,lmax,nvar,ntype,nlvdi
	integer nvar0,lmax0,np0
	integer idt,idtact
	double precision dtime,atmin,atmax,atime0,atime1997
	double precision atime,atimeold,atimeanf,atimeend
	real dmin,dmax
	integer ierr
	integer nfile
	integer irec,iv,ich,isk,nrecs,iu88,l,i
	integer itype(2)
	integer iformat,iformout
	integer datetime(2),dateanf(2),dateend(2)
	integer iextract,it
	integer ie,nx,ny,ix,iy
	real regpar(7)
	logical bdebug,bfirst,bskip,bwrite,bout,btmin,btmax,boutput
	logical bquiet,bhuman,blayer
	logical bchform,bcheckdt,bdtok,bextract,breg,bintime
	logical bsplit,bread
	character*80, allocatable :: strings(:)
	character*20 line,aline
	character*40 eformat
	character*80 stmin,stmax
	real,allocatable :: data(:,:,:)
	real,allocatable :: dext(:)
	real,allocatable :: d3dext(:,:)
	real,allocatable :: hd(:)
	real,allocatable :: hlv(:)
	integer,allocatable :: ilhkv(:)
	integer,allocatable :: ius(:)

	integer ifileo

	bdebug = .true.
	bdebug = .false.
	bhuman = .true.		!convert time in written fem file to dtime=0
	blayer = .true.		!write layer structure - should be given by CLO
	blayer = .false.

	iextract = 0
	iu88 = 0
	datetime = 0
	datetime(1) = 19970101
	dtime = 0.
	call dts_convert_to_atime(datetime,dtime,atime)
	atime1997 = atime

        datetime = 0
        irec = 0

	call clo_get_option('write',bwrite)
	call clo_get_option('out',bout)
        call clo_get_option('node',iextract)
        call clo_get_option('split',bsplit)
	call clo_get_option('chform',bchform)
	call clo_get_option('quiet',bquiet)
        call clo_get_option('checkdt',bcheckdt)
	call clo_get_option('tmin',stmin)
	call clo_get_option('tmax',stmax)

	if( bchform ) bout = .true.
	bextract = iextract > 0

	atmin = 0.
	atmax = 0.
	btmin = stmin .ne. ' '
	btmax = stmax .ne. ' '
	if( btmin ) call dts_string2time(stmin,atmin)
	if( btmax ) call dts_string2time(stmax,atmax)

	!write(6,*) stmin(1:len_trim(stmin)),btmin,atmin
	!write(6,*) stmax(1:len_trim(stmax)),btmax,atmax
	
c--------------------------------------------------------------
c open file
c--------------------------------------------------------------

	if( infile .eq. ' ' ) stop

	np = 0
	call fem_file_read_open(infile,np,iformat,iunit)
	if( iunit .le. 0 ) stop

	write(6,*) 'file name: ',infile(1:len_trim(infile))
	call fem_file_get_format_description(iformat,line)
	write(6,*) 'format: ',iformat,"  (",line(1:len_trim(line)),")"

c--------------------------------------------------------------
c prepare for output if needed
c--------------------------------------------------------------

        iout = 0
	iformout = iformat
	if( bchform ) iformout = 1 - iformat
	if( iformout < 0 ) iformout = iformat

        if( bout ) then
          iout = iunit + 1
          if( iformout .eq. 1 ) then
	    open(iout,file='out.fem',status='unknown',form='formatted')
          else
	    open(iout,file='out.fem',status='unknown',form='unformatted')
          end if
        end if

c--------------------------------------------------------------
c read first record
c--------------------------------------------------------------

        call fem_file_read_params(iformat,iunit,dtime
     +                          ,nvers,np,lmax,nvar,ntype,datetime,ierr)

	if( ierr .ne. 0 ) goto 99

	if( .not. bquiet ) then
	  write(6,*) 'nvers:  ',nvers
	  write(6,*) 'np:     ',np
	  write(6,*) 'lmax:   ',lmax
	  write(6,*) 'nvar:   ',nvar
	  write(6,*) 'ntype:  ',ntype
	end if

	allocate(hlv(lmax))
	call fem_file_make_type(ntype,2,itype)

	call fem_file_read_2header(iformat,iunit,ntype,lmax
     +			,hlv,regpar,ierr)
	if( ierr .ne. 0 ) goto 98

	if( lmax > 1 .and. .not. bquiet ) then
	  write(6,*) 'vertical layers: ',lmax
	  write(6,*) hlv
	end if
	if( itype(1) .gt. 0 .and. .not. bquiet ) then
	  write(6,*) 'date and time: ',datetime
	end if
	breg = .false.
	if( itype(2) .gt. 0 .and. .not. bquiet ) then
	  breg = .true.
	  write(6,*) 'regpar: ',regpar
	end if

	call dts_convert_to_atime(datetime,dtime,atime)
	atime0 = atime		!absolute time of first record

	if( bextract ) then
	  bskip = .false.
	  if( iextract > np ) goto 91
	  if( breg ) then
	    ie = iextract
	    nx = nint(regpar(1))
	    ny = nint(regpar(2))
	    iy = 1 + (ie-1) / nx
	    ix = ie - (iy-1)*nx
	    write(6,*) 'regular grid:     ',nx,ny
	    write(6,*) 'extracting point: ',ix,iy
	  else
	    write(6,*) 'extracting point: ',iextract
	  end if
	  iu88 = ifileo(88,'out.txt','form','new')
	  write(iu88,'(a,2i10)') '#date: ',datetime
	  write(eformat,'(a,i3,a)') '(i12,',nvar,'g14.6,a2,a20)'
	  write(6,*) 'using format: ',trim(eformat)
	end if

	nvar0 = nvar
	lmax0 = lmax
	nlvdi = lmax
	np0 = np
	allocate(strings(nvar))
	allocate(dext(nvar))
	allocate(d3dext(nlvdi,nvar))
	allocate(data(nlvdi,np,nvar))
	allocate(hd(np))
	allocate(ilhkv(np))
	allocate(ius(nvar))
	ius = 0

	do iv=1,nvar
	  call fem_file_skip_data(iformat,iunit
     +                          ,nvers,np,lmax,string,ierr)
	  if( ierr .ne. 0 ) goto 97
	  if( .not. bquiet ) write(6,*) 'data:   ',iv,'  ',trim(string)
	  strings(iv) = string
	end do

c--------------------------------------------------------------
c close and re-open file
c--------------------------------------------------------------

	close(iunit)

	np = 0
	call fem_file_read_open(infile,np,iformat,iunit)
	if( iunit .le. 0 ) stop

c--------------------------------------------------------------
c loop on all records
c--------------------------------------------------------------

	irec = 0
	idt = 0
	ich = 0
	isk = 0
	atimeanf = atime
	atimeend = atime
	atimeold = atime - 1

	do 
	  irec = irec + 1
          call fem_file_read_params(iformat,iunit,dtime
     +                          ,nvers,np,lmax,nvar,ntype,datetime,ierr)
	  if( ierr .lt. 0 ) exit
	  if( ierr .gt. 0 ) goto 99
	  if( nvar .ne. nvar0 ) goto 96
	  if( lmax .ne. lmax0 ) goto 96
	  if( np .ne. np0 ) goto 96

	  call dts_convert_to_atime(datetime,dtime,atime)
	  call dts_format_abs_time(atime,line)

	  if( bdebug ) write(6,*) irec,atime,line

	  call fem_file_read_2header(iformat,iunit,ntype,lmax
     +			,hlv,regpar,ierr)
	  if( ierr .ne. 0 ) goto 98

	  bdtok = atime > atimeold
          boutput = bout .and. bdtok
	  bread = bwrite .or. bextract .or. boutput
	  bread = bread .or. bsplit
	  bskip = .not. bread
	  bintime = .true.
	  if( btmin ) bintime = bintime .and. atime >= atmin
	  if( btmax ) bintime = bintime .and. atime <= atmax
	  boutput = boutput .and. bintime
	  if( .not. bintime ) bskip = .true.

          if( boutput ) then
	    if( bhuman ) then
	      call dts_convert_from_atime(datetime,dtime,atime)
	    end if
            call fem_file_write_header(iformout,iout,dtime
     +                          ,0,np,lmax,nvar,ntype,lmax
     +                          ,hlv,datetime,regpar)
          end if

	  do iv=1,nvar
	    if( bskip ) then
	      call fem_file_skip_data(iformat,iunit
     +                          ,nvers,np,lmax,string,ierr)
	    else
              call fem_file_read_data(iformat,iunit
     +                          ,nvers,np,lmax
     +                          ,string
     +                          ,ilhkv,hd
     +                          ,nlvdi,data(1,1,iv)
     +                          ,ierr)
	    end if
	    if( ierr .ne. 0 ) goto 97
	    if( string .ne. strings(iv) ) goto 95
            if( boutput ) then
	      !call custom_elab(nlvdi,np,string,iv,data(1,1,iv))
              call fem_file_write_data(iformout,iout
     +                          ,0,np,lmax
     +                          ,string
     +                          ,ilhkv,hd
     +                          ,nlvdi,data(1,1,iv))
            end if
	    if( bwrite .and. .not. bskip ) then
	     if( blayer ) then
	      do l=1,lmax
               call minmax_data(l,lmax,np,ilhkv,data(1,1,iv),dmin,dmax)
	       write(6,1200) irec,iv,l,atime,dmin,dmax,line
 1200	       format(i6,i3,i4,f15.2,2g14.5,1x,a20)
	      end do
	     else
              call minmax_data(0,lmax,np,ilhkv,data(1,1,iv),dmin,dmax)
	      write(6,1100) irec,iv,atime,dmin,dmax,line
 1100	      format(i6,i3,f15.2,2g16.5,1x,a20)
	     end if
	    end if
	    if( bextract ) then
	      dext(iv) = data(1,iextract,iv)
	      d3dext(:,iv) = data(:,iextract,iv)
	    end if
	    if( bsplit ) then
	      call femsplit(iformout,ius(iv),dtime,nvers,np
     +			,lmax,nlvdi,ntype
     +			,hlv,datetime,regpar,string
     +			,ilhkv,hd,data(:,:,iv))
	    end if
	  end do

	  if( bextract .and. bdtok .and. bintime ) then
	    it = nint(atime-atime0)
	    it = nint(atime-atime1997)
	    call dts_format_abs_time(atime,aline)
	    write(iu88,eformat) it,dext,'  ',aline
	  end if

	  call check_dt(atime,atimeold,bcheckdt,irec,idt,ich,isk)
	  atimeold = atime
	  if( .not. bdtok ) cycle

	  atimeend = atime
	end do

c--------------------------------------------------------------
c finish loop - info on time records
c--------------------------------------------------------------

	nrecs = irec - 1
	write(6,*) 'nrecs:  ',nrecs
	call dts_format_abs_time(atimeanf,line)
	write(6,*) 'start time: ',atimeanf,line
	call dts_format_abs_time(atimeend,line)
	write(6,*) 'end time:   ',atimeend,line

        if( ich == 0 ) then
          write(6,*) 'idt:    ',idt
        else
          write(6,*) 'idt:     irregular ',ich,isk
        end if

	if( isk .gt. 0 ) then
	  write(6,*) '*** warning: records eliminated: ',isk
	end if

	close(iunit)
	if( iout > 0 ) close(iout)

	if( bout ) then
	  write(6,*) 'output written to file out.fem'
	end if

	if( bextract ) then
	  write(6,*) 'iextract = ',iextract
	  write(6,*) 'data written to out.txt'
	end if

c--------------------------------------------------------------
c end of routine
c--------------------------------------------------------------

	return
   91	continue
	write(6,*) 'iectract,np: ',iextract,np
	stop 'error stop femelab: no such node'
   95	continue
	write(6,*) 'strings not in same sequence: ',iv
        write(6,*) string
        write(6,*) strings(iv)
	stop 'error stop femelab: strings'
   96	continue
	write(6,*) 'nvar,nvar0: ',nvar,nvar0
	write(6,*) 'lmax,lmax0: ',lmax,lmax0	!this might be relaxed
	write(6,*) 'np,np0:     ',np,np0	!this might be relaxed
	write(6,*) 'cannot change number of variables'
	stop 'error stop femelab'
   97	continue
	write(6,*) 'record: ',irec
	write(6,*) 'cannot read data record of file'
	stop 'error stop femelab'
   98	continue
	write(6,*) 'record: ',irec
	write(6,*) 'cannot read second header of file'
	stop 'error stop femelab'
   99	continue
	write(6,*) 'record: ',irec
	write(6,*) 'cannot read header of file'
	stop 'error stop femelab'
	end

c*****************************************************************
c*****************************************************************
c*****************************************************************

        subroutine minmax_data(level,nlvddi,np,ilhkv,data,vmin,vmax)

        implicit none

	integer level		!level for which minmax to compute (0 for all)
        integer nlvddi,np
        integer ilhkv(1)
        real data(nlvddi,1)
	real vmin,vmax

        integer k,l,lmin,lmax,lm
        real v

	lmin = max(1,level)
	lmax = level
	if( level == 0 ) lmax = nlvddi

        vmin = data(1,1)
        vmax = data(1,1)

        do k=1,np
          lm = min(ilhkv(k),lmax)
          do l=lmin,lm
            v = data(l,k)
            vmax = max(vmax,v)
            vmin = min(vmin,v)
          end do
        end do

        !write(86,*) 'min/max: ',it,vmin,vmax

        end

c*****************************************************************

	subroutine check_dt(atime,atimeold,bcheckdt,irec,idt,ich,isk)

	implicit none

	double precision atime,atimeold
	logical bcheckdt
	integer irec,idt,ich,isk

	integer idtact
	character*20 aline

          if( irec > 1 ) then
            if( irec == 2 ) idt = nint(atime-atimeold)
            idtact = nint(atime-atimeold)
            if( idtact .ne. idt ) then
              ich = ich + 1
              if( bcheckdt ) then
		call dts_format_abs_time(atime,aline)
                write(6,'(a,3i10,a,a)') '* change in time step: '
     +                          ,irec,idt,idtact,'  ',aline
              end if
              idt = idtact
            end if
            if( idt <= 0 ) then
	      isk = isk + 1
	      call dts_format_abs_time(atime,aline)
              write(6,*) '*** zero or negative time step: ',irec,idt
     +                          ,atime,atimeold,'  ',aline
            end if
          end if

	end

c*****************************************************************

	subroutine write_extract(atime,atime0,datetime
     +					,nvar,lmax,dext,d3dext)

	implicit none

	double precision atime,atime0
	integer datetime(2)
	integer nvar,lmax
	real dext(nvar)
	real d3dext(lmax,nvar)

	integer, save :: iu2d = 0
	integer, save :: iu3d = 0

	integer it
	double precision dtime
	character*80 eformat
	character*20 aline

	integer ifileo

	if( iu2d == 0 ) then
	  iu2d = ifileo(88,'out.txt','form','new')
	  write(iu2d,'(a,2i10)') '#date: ',datetime
	  write(eformat,'(a,i3,a)') '(i12,',nvar,'g14.6,a2,a20)'
	  write(6,*) 'using format: ',trim(eformat)
	end if
	if( iu2d == 0 ) then
	  iu3d = ifileo(89,'out.fem','form','new')
	end if

	dtime = atime-atime0
	it = nint(dtime)
	!it = nint(atime-atime1997)
	call dts_format_abs_time(atime,aline)
	write(iu2d,eformat) it,dext,'  ',aline

!	nvers
!        call fem_file_write_header(iformat,iu3d,dtime
!     +                          ,nvers,np,lmax
!     +                          ,nvar,ntype
!     +                          ,nlvddi,hlv,datetime,regpar)
!        call fem_file_write_data(iformat,iu3d
!     +                          ,nvers,np,lmax
!     +                          ,string
!     +                          ,ilhkv,hd
!     +                          ,nlvddi,temp1)

	end

c*****************************************************************

	subroutine femsplit(iformout,ius,dtime,nvers,np
     +			,lmax,nlvddi,ntype
     +			,hlv,datetime,regpar,string
     +			,ilhkv,hd,data)

	implicit none

	integer iformout,ius
	double precision dtime
	integer nvers,np,lmax,nlvddi,ntype
	real hlv(lmax)
	integer datetime(2)
	real regpar(7)
	character(*) string
	integer ilhkv(np)
	real hd(np)
	real data(nlvddi,np)

	integer ivar,nvar
	character*80 file,extra
	character*1 dir
	integer, save :: iusold

	if( ius == 0 ) then
	  call string2ivar(string,ivar)
	  call string_direction(string,dir)
	  if( dir == 'y' ) then		!is second part of vector
	    ius = iusold
	  else
	    call alpha(ivar,extra)
	    file = 'out.' // trim(extra) // '.fem'
	    call fem_file_write_open(file,iformout,ius)
	    if( ius <= 0 ) goto 99
	    iusold = ius
	  end if
	end if

	nvar = 1
	if( dir /= ' ' ) nvar = 2

	if( dir /= 'y' ) then
          call fem_file_write_header(iformout,ius,dtime
     +                          ,nvers,np,lmax
     +                          ,nvar,ntype
     +                          ,nlvddi,hlv,datetime,regpar)
	end if

        call fem_file_write_data(iformout,ius
     +                          ,nvers,np,lmax
     +                          ,string
     +                          ,ilhkv,hd
     +                          ,nlvddi,data)

	return
   99	continue
	write(6,*) 'cannot open file ',trim(file)
	stop 'error stop femsplit: cannot open output file'
	end

c*****************************************************************

	subroutine custom_elab(nlvdi,np,string,iv,data)

	implicit none

	integer nlvdi,np,iv
	character*(*) string
	real data(nlvdi,np)

	real fact

	return

	if( string(1:13) /= 'wind velocity' ) return
	if( iv < 1 .or. iv > 2 ) return

	fact = 2.

	!write(6,*) iv,'  ',trim(string)
	write(6,*) 'attention: wind speed changed by a factor of ',fact

	data = fact * data

	end

c*****************************************************************

