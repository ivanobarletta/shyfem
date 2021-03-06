c
c $Id: subsse.f,v 1.25 2009-04-03 16:38:23 georg Exp $
c
c interpolation routines
c
c contents :
c
c subroutine intp_lsqr(nn,ndiff,xx,xee)	least square interpolation
c function intp_lagr(n,x,y,xe)		lagrangian interpolation
c
c function tcomp(nintp,t)		t where new value has to be read
c subroutine intp_ts(iunit,nintp,nvar,t,vars,rint,b3d)
c		interpolation directly from file (more files, multiple columns)
c
c subroutine read_time_series(unit,nvar,b3d,time,values,ierr)
c		time series read
c subroutine read_0_time_series(unit,nvar,time,values,ierr)
c		classic time series read:  time,val1,val2,val3,...valn
c subroutine read_3_time_series(unit,nvar,time,values,ierr)
c		3D time series read
c
c function exxpp(nintp,nmax,x,y,xe,istart)	interpolation from array
c function rintq(...)			interpolation in a square
c
c exf routines (see later)
c
c revision log :
c
c 29.06.1998	ggu	error check in exxqq9
c 14.07.1998	ggu	new routine exxqq
c 21.08.1998	ggu	xv renamed to xx
c 31.05.2001	ggu	revised exxp (style) and exxpp (error fix and grade)
c 12.02.2003	ggu	return constant if t is out of range in exxqq
c 11.03.2005	ggu	new interpolation also for 3D time series
c 16.05.2005	ggu	more debug and new error messages
c 01.02.2006	ggu	new routine exfpres() for pointer to results
c 17.02.2006	ggu	set iunit to -1 if no file given (exffil)
c 29.02.2008	ggu	name change: exxp -> intp_lagr, extrp -> intp_lsqr
c 29.02.2008	ggu	deleted exxqq, exxqq9
c 17.03.2008	ggu	completely restructured
c 18.04.2008	ggu	new exffild, adjusted exffil, bugfix in exfini, exfintp
c 03.09.2008	ggu	bug fix in intp_ts, bug fix in exfini (aux array)
c 08.10.2008	ggu	introduced matinv0 for independence
c 08.11.2008	ggu	better error handling
c 02.04.2009	ggu	if less data given lower interpolation (REDINT)
c 03.04.2009	ggu	new routine intp_neville() (stable lagrange interpol.)
c
c**************************************************
c
	subroutine intp_lsqr(nn,ndiff,xx,xee)
c
c interpolation by least square method
c
c nn		number of points used (4=cubic)
c ndiff		number of grades the interpolating polynome
c		...is lowered (normally 1)
c xx		on entry  : x-values used for interpolation
c		on return : c-values, that have to be used
c		...in computing interpolated y-value -->
c		...ye=c(i)*y(i) ; i=1,n
c xee		x-value for which y-value has to be computed
c
	parameter(iexpmx=5,idim=iexpmx+1)
	real x(idim,idim),a(idim,idim)
	real b(idim,idim)
	real xx(idim),xe(idim)
	integer ip(idim)
c
	if(nn.le.ndiff) goto 99
	if(ndiff.le.0) goto 98
	if(nn.gt.iexpmx+1) goto 97
c
	n=nn-ndiff
c
	do ii=1,nn
	x(ii,1)=1.
	do i=2,n
	x(ii,i)=x(ii,i-1)*xx(ii)
	end do
	end do
c
	do i=1,n
	do j=1,n
	h=0.
	do ii=1,nn
	h=h+x(ii,j)*x(ii,i)
	end do
	a(i,j)=h
	end do
	end do
c
	call matinv0(a,ip,xe,n,idim)	!xx,xe aux vectors
c
	do i=1,n
	do ii=1,nn
	h=0.
	do j=1,n
	h=h+a(i,j)*x(ii,j)
	end do
	b(i,ii)=h
	end do
	end do
c
	xe(1)=1.
	do i=2,n
	xe(i)=xe(i-1)*xee
	end do
c
	do ii=1,nn
	h=0.
	do i=1,n
	h=h+b(i,ii)*xe(i)
	end do
	xx(ii)=h
	end do
c
	return
c
   97	continue
	write(6,*) 'dimension error'
	write(6,*) 'iexpmx,nn :',iexpmx,nn
	stop 'error stop : intp_lsqr'
c
   98	continue
	write(6,*) 'ndiff must be greater than 0'
	write(6,*) 'ndiff =',ndiff
	stop 'error stop : intp_lsqr'
c
   99	continue
	write(6,*) 'nn must be greater than ndiff'
	write(6,*) 'nn,ndiff =',nn,ndiff
	stop 'error stop : intp_lsqr'
c
	end

c**********************************************

        subroutine matinv0(a,ip,hv,n,nd)

c inversion of square matrix (no band matrix) (original in subssm.f)
c
c a             square matrix
c ip            aux vector for pivot search
c hv            aux vector for resolution of matrix
c n             actual dimension of matrix
c nd            formal dimension of matrix

        parameter (eps=1.e-30)
        real a(nd,nd),hv(nd)
        integer ip(nd)

        do j=1,n
          ip(j)=j
        end do

        do j=1,n

c look for pivot

        amax=abs(a(j,j))
        ir=j
        do i=j+1,n
          if(abs(a(i,j)).gt.amax) then
            amax=abs(a(i,j))
            ir=i
          end if
        end do
        if(amax.lt.eps) goto 99

c change row

        if(ir.gt.j) then
          do k=1,n
            hr=a(j,k)
            a(j,k)=a(ir,k)
            a(ir,k)=hr
          end do
          ihi=ip(j)
          ip(j)=ip(ir)
          ip(ir)=ihi
        end if

c transformation

        hr=1./a(j,j)
        do i=1,n
          a(i,j)=hr*a(i,j)
        end do
        a(j,j)=hr
        do k=1,n
          if(k.ne.j) then
            do i=1,n
              if(i.ne.j) a(i,k)=a(i,k)-a(i,j)*a(j,k)
            end do
            a(j,k)=-hr*a(j,k)
          end if
        end do

        end do

c change column

        do i=1,n
          do k=1,n
            ipk=ip(k)
            hv(ipk)=a(i,k)
          end do
          do k=1,n
            a(i,k)=hv(k)
          end do
        end do

        return

   99   continue
        write(6,*) 'matrix singular. cannot invert matrix'
        write(6,*) 'i,j,amax(i,j) :',ir,j,amax
        stop 'error stop : matinv0'

        end

c**********************************************

	function intp_neville_not_working(nintp,x,y,xe)

c interpolation routine (Lagrangian interpolation)
c
c intp_neville	interpolated y-value for xe
c nintp		number of points used for interpolation (4=cubic)
c x,y		x/y-values (vector) ( x(i) != x(j) for i != j )
c xe		x-value for which y-value has to computed

	implicit none

	real intp_neville_not_working
	integer nintp
	real x(nintp),y(nintp)
	real xe

	integer ndim
	parameter (ndim=5)

	integer i,k,n
	double precision dq,xx,accum
	double precision q(ndim,ndim),d(ndim,ndim)

	if( nintp .gt. ndim ) stop 'error stop intp_neville: ndim'

	n = nintp

	k = 1
	do i=1,n
	  q(i,k) = y(i)
	  d(i,k) = y(i)
	end do

	do k=2,n
	  do i=k,n
	    dq = d(i,k-1) - q(i-1,k-1)
	    xx = x(i-k) - x(i)
	    q(i,k) = dq * ( x(i) - xe ) / xx
	    d(i,k) = dq * ( x(i-k) - xe ) / xx
	  end do
	end do

	accum = 0.
	do k=2,n
	  accum = accum + q(n,k)
	end do

	intp_neville_not_working = y(n) + accum

	end

c**********************************************

        function intp_neville(nintp,xa,ya,x)

c use Neville algorithm for Lagrangian interpolation
c
c use nintp=4 for cubic interpolation
c use nintp=2 for linear interpolation

        implicit none

        integer ndim
        parameter (ndim=10)

        real intp_neville			!interpolated value
        integer nintp				!grade of interpolation
        real xa(0:nintp-1), ya(0:nintp-1)	!points to use
        real x					!where to interpolate

        integer i,k,n
        double precision xl,xh
        double precision p(0:ndim)

        if( nintp .gt. ndim ) stop 'error stop neville: ndim'

        n = nintp - 1

        do i=0,n
          p(i) = ya(i)
        end do

        do k=1,n
          do i=n,k,-1
            xl = xa(i-k)
            xh = xa(i)
            p(i) = ( (x-xl)*p(i) - (x-xh)*p(i-1) ) / (xh-xl)
          end do
        end do

        intp_neville = p(n)

        end

c**********************************************

	function intp_lagr(nintp,x,y,xe)

c interpolation routine (Lagrangian interpolation)
c
c this algorithm is unstable ... please use intp_neville()
c
c intp_lagr	interpolated y-value for xe
c nintp		number of points used for interpolation (4=cubic)
c x,y		x/y-values (vector) ( x(i) != x(j) for i != j )
c xe		x-value for which y-value has to computed

	implicit none

	real intp_lagr
	integer nintp
	real x(nintp),y(nintp)
	real xe

	integer i,ii
	double precision f,g

	f=0.
	do i=1,nintp
	  g=1.
	  do ii=1,nintp
	    if(i.ne.ii) then
		g=g*(xe-x(ii))/(x(i)-x(ii))
	    end if
	  end do
	  f=f+y(i)*g
	end do

	intp_lagr=f

	end

c*************************************************************

	function tcomp(ndata,nintp,t)

c returns value of t where new value has to be read

	implicit none

	real tcomp
	integer ndata
	integer nintp
	real t(0:ndata,nintp+1)

	integer nold,n1,n2
	save nold,n1,n2
	data nold / 0 /		!impossible value

c----------------------------------------------------------
c if value of nintp has changed -> compute new n1,n2
c
c we could compute this every time, but this slightly more efficient
c----------------------------------------------------------

	if( nintp .ne. nold ) then

	    if( mod(nintp,2) .eq. 0 ) then	!even
		n1=1+nintp/2
		n2=n1
	    else
		n1=1+nintp/2
		if(nintp.gt.1) then
			n2=n1+1
		else
			n2=n1
		end if
	    end if

	    nold = nintp

	end if

c----------------------------------------------------------
c return compare value
c----------------------------------------------------------

	tcomp = 0.5 * ( t(0,n1) + t(0,n2) )

c----------------------------------------------------------
c end of routine
c----------------------------------------------------------

	end

c*************************************************************

        subroutine exxqq(iunit,nintp,nvar,t,vars,rint)
	real vars(0:nvar,nintp)
	real rint(nvar)
        call intp_ts(iunit,nintp,nvar,t,vars,rint,.false.)
        end

        subroutine intp_0_ts(iunit,nintp,nvar,t,vars,rint)
	real vars(0:nvar,nintp)
	real rint(nvar)
        call intp_ts(iunit,nintp,nvar,t,vars,rint,.false.)
        end

        subroutine intp_3_ts(iunit,nintp,nvar,t,vars,rint)
	real vars(0:nvar,nintp)
	real rint(nvar)
        call intp_ts(iunit,nintp,nvar,t,vars,rint,.true.)
        end

c*************************************************************

	subroutine intp_ts(iunit,nintp,ndata,t,vars,rint,b3d)

c interpolation directly from file (more files and multiple columns)
c
c interpolation of values read directly from formatted file
c t values must be in increasing order
c rt values for which interpolation has to be performed
c ...must be called for in increasing order
c works also for one point interpolation
c
c iunit		file number from which data is read (if negative reset file)
c nintp		number of points used for interpolation
c ndata		number of data in time step
c t		t value for which y values have to be found
c vars		array with working variables already read
c rint		array of interpolated return values at time t
c b3d		if file format is 3D or 0D
c
c calls: read_time_series, intp_neville, tcomp

	implicit none

c arguments
	integer iunit
	integer nintp
	integer ndata
	real t
	!real vars(0:ndata,nintp+1)	!error -> only data, not results
	real vars(0:ndata,nintp)
	real rint(ndata)
        logical b3d
c local
	integer ndim
	parameter (ndim=5)
	integer unit
	integer i,j,ierr
	real tc,time
	character*70 name
	real x(ndim), y(ndim)
c functions
	real intp_neville
	real tcomp
c save
	logical bdebug
	real eps
	save eps,bdebug
	data eps / 1.e-5 /
	data bdebug / .false. /

c----------------------------------------------------------
c some checks
c----------------------------------------------------------

	if( nintp .le. 0 ) goto 90
	if( nintp .gt. ndim ) goto 90

        !b3d = .false.

c----------------------------------------------------------
c rewind if necessary
c----------------------------------------------------------

	unit = iunit

	if( unit .lt. 0 ) then	!reset file
		unit = -unit
		rewind(unit)

		if( bdebug ) then
		  write(6,*) 'intp_ts: (Initializing unit) ',unit
		  write(6,*) unit,ndata,b3d,t
		end if

		do i=1,nintp
		  if(bdebug) write(6,*) 'intp_ts: (reading initial data) ',i
                  call read_time_series(unit,ndata,b3d,time,rint,ierr)
                  if( ierr .gt. 0 ) goto 95
                  !if( ierr .lt. 0 ) goto 94
                  if( ierr .lt. 0 ) goto 2	!REDINT
                  vars(0,i) = time
		  do j=1,ndata
		    vars(j,i) = rint(j)
                  end do
		  if( bdebug ) write(6,*) (vars(j,i),j=0,ndata)
		end do
    2		continue
		if( i .ne. nintp+1 ) then	!reduce intpol if less data
		  write(6,*) '------------------------------'
		  write(6,*) 'file contains not enough data'
		  write(6,*) 'unit,nintp: ',unit,nintp
		  write(6,*) 'at least ',nintp,' data needed'
		  nintp = i - 1
		  write(6,*) 'using lower interpolation: ',nintp
		  write(6,*) '------------------------------'
		end if

		if( nintp .gt. 1 ) then		!check time values
		  do i=2,nintp
		    if( vars(0,i) .le. vars(0,i-1) ) goto 87
		  end do
		end if

		return
	else if( unit .eq. 0 ) then
		goto 93
	end if

c----------------------------------------------------------
c get new t value
c----------------------------------------------------------

	tc = tcomp(ndata,nintp,vars)	!critical t when to read new values

	do while( t .gt. tc )
		!write(6,*) 'reading data for boundary: ',i,t,tc,b3d
                call read_time_series(unit,ndata,b3d,time,rint,ierr)
                if( ierr .gt. 0 ) goto 96
                if( ierr .lt. 0 ) goto 1

		do i=1,nintp-1
		  do j=0,ndata
		    vars(j,i) = vars(j,i+1)
                  end do
		end do

                vars(0,nintp) = time
		do j=1,ndata
		  vars(j,nintp) = rint(j)
                end do

		if( nintp .gt. 1 ) then		!check time value
		  if( vars(0,nintp) .le. vars(0,nintp-1) ) goto 87
		end if

		tc = tcomp(ndata,nintp,vars)     !pass in time column
	end do
    1	continue

c----------------------------------------------------------
c debug output
c----------------------------------------------------------

	if( bdebug ) then
	  write(6,*) 'debug for intp_ts: '
	  do i=1,nintp
	    write(6,*) (vars(j,i),j=0,ndata)
	  end do
	end if

c----------------------------------------------------------
c time series must have t value monotonically increasing
c----------------------------------------------------------

	do i=2,nintp
	    if( vars(0,i) .le. vars(0,i-1) ) goto 88
	end do

c----------------------------------------------------------
c check if we are really doing an interpolation
c----------------------------------------------------------

	if( nintp .gt. 1 ) then			!no check for nintp = 1
		i = 0
		if( t .lt. vars(0,1)-eps ) i = 1
		if( t .gt. vars(0,nintp)+eps ) i = nintp
		if( i .gt. 0 ) then	!keep constant
		  do j=1,ndata
		    rint(j) = vars(j,i)
		  end do
		  return
		end if
	end if

c----------------------------------------------------------
c do the interpolation for every column
c----------------------------------------------------------

	do i=1,nintp
	  x(i) = vars(0,i)
	end do

	do j=1,ndata
	  do i=1,nintp
	    y(i) = vars(j,i)
	  end do
	  rint(j) = intp_neville(nintp,x,y,t)
	end do

c----------------------------------------------------------
c end of routine
c----------------------------------------------------------

	return
   87	continue
	write(6,*) 'time values not in ascending order'
	write(6,*) 'unit = ',unit
	write(6,*) 'nintp = ',nintp
	write(6,*) 'time: ',(vars(0,i),i=1,nintp)
	stop 'error stop : intp_ts'
   88	continue
	write(6,*) 't values are not in increasing order:'
	write(6,*) 'Available time levels :'
	write(6,*) (vars(0,i),i=1,nintp)
	write(6,*) 'interpolation grade = ',nintp
	write(6,*) 't = ',t
	write(6,*) 'unit = ',unit
	call filna(iunit,name)
	write(6,'(a,a)') 'file = ',name
	stop 'error stop : intp_ts'
   90	continue
	write(6,*) 'Value for nintp out of range: ',nintp
	write(6,*) 'Possible min/max values: ',1,ndim
	stop 'error stop : intp_ts'
   91	continue
	write(6,*) 'No extrapolation possible'
	write(6,*) 'Actual t value :',t
	write(6,*) 'Available time levels :'
	write(6,*) (vars(0,i),i=1,nintp)
	stop 'error stop : intp_ts'
   93	continue
	write(6,*) 'Cannot read from unit 0'
	stop 'error stop : intp_ts'
   94	continue
	write(6,*) 'End of file while initializing on unit :',unit
	write(6,*) 'i,nintp,ndata: ',i,nintp,ndata
	write(6,*) 'time: ',time
	write(6,*) 'File must consist of at least ',nintp,' data'
	stop 'error stop : intp_ts'
   95	continue
	write(6,*) 'Read error while initializing from file :',unit
	write(6,*) 'i,nintp,ndata: ',i,nintp,ndata
	write(6,*) 'time: ',time
	write(6,*) (rint(i),i=1,ndata)
	write(6,*) 'Attention : Cannot read unformatted file'
	stop 'error stop : intp_ts'
   96	continue
	write(6,*) 'Read error from file :',unit
	write(6,*) 'nintp,ndata: ',nintp,ndata
	write(6,*) 't,tc,time: ',t,tc,time
	write(6,*) (rint(i),i=1,ndata)
	stop 'error stop : intp_ts'
	end

c*************************************************************

        subroutine read_time_series(unit,ndata,b3d,time,values,ierr)

c time series read

        implicit none

        integer unit
        integer ndata
	logical b3d			!true if 3d read
        real time
        real values(ndata)
        integer ierr

	if( b3d ) then
          call read_3_time_series(unit,ndata,time,values,ierr)
	else
          call read_0_time_series(unit,ndata,time,values,ierr)
	end if

	end

c*************************************************************

        subroutine read_0_time_series(unit,nvar,time,values,ierr)

c classic time series read:  time,val1,val2,val3,...valn

        implicit none

        integer unit
        integer nvar
        real time
        real values(nvar)
        integer ierr

        integer j

	read(unit,*,iostat=ierr) time,(values(j),j=1,nvar)

        end

c*************************************************************

        subroutine read_3_time_series(unit,ndata,time,values,ierr)

c 3D time series read:  
c
c       time,lmax,nk,nvar
c       values

        implicit none

        integer unit
        integer ndata
        real time
        real values(ndata)
        integer ierr

        integer j,n,lmax,nk,nvar
        integer ip,ivar,k,kn
	logical bdebug
	character*80 name

	bdebug = .true.
	bdebug = .false.

	if( bdebug ) write(6,*) '3d TS read : ',unit,ndata

	read(unit,*,iostat=ierr) time,lmax,nk,nvar
	if( bdebug ) write(6,*) time,lmax,nk,nvar
	n = 0
        if( ierr .gt. 0 ) goto 97
        if( ierr .lt. 0 ) return
        n = lmax * nk * nvar
        if( n .ne. ndata ) goto 99

        ip = 0
        do ivar=1,nvar
          do k=1,nk
	    read(unit,*,iostat=ierr) kn,(values(ip+j),j=1,lmax)
	    !write(6,*) k,kn,(values(ip+j),j=1,lmax)
            if( kn .ne. k ) goto 98
            ip = ip + lmax
          end do
        end do

	if( bdebug ) write(6,*) '3d TS read (last ip) : ',unit,ip

        return
   97   continue
	call filna(unit,name)
        write(6,*) 'read error on unit: ',unit,' with file name: '
	write(6,*) name
        write(6,*) time,lmax,nk,nvar
	write(6,*) 'error reading header of data set'
        stop 'error stop read_3_time_series: header'
   98   continue
	call filna(unit,name)
        write(6,*) 'read error on unit: ',unit,' with file name: '
	write(6,*) name
        write(6,*) time,lmax,nk,nvar
        write(6,*) k,kn
        write(6,*) '(node number not compatible)'
        stop 'error stop read_3_time_series: nk'
   99   continue
	call filna(unit,name)
        write(6,*) 'read error on unit: ',unit,' with file name: '
	write(6,*) name
        write(6,*) time,lmax,nk,nvar
        write(6,*) n,ndata
        write(6,*) '(data set may not be compatible)'
        write(6,*) 'calling routine wants ',ndata,' data'
        write(6,*) 'data file provides    ',n,' data'
        write(6,*) 'There could be a mismatch between nbdim and lmax'
        write(6,*) 'In this case please set nbdim in STR to'
        write(6,*) 'lmax given in data file'
        stop 'error stop read_3_time_series: ndata'
        end

c*************************************************************

	function exxpp(nintp,nmax,x,y,xe,iact)

c interpolation from array
c
c from given values x,y a value ye corresponding
c to xe is interpolated. a cubic interpolation is used
c
c the program is looking for the closest x-value
c only in foreward direction. for this reason
c xe-values must be passed in an increasing sequence
c
c the program does not check, if the value of xe
c is in the bounds of x(1) - x(nmax)
c eventually an extrapolated value is returned in exxpp

	implicit none

	real exxpp	!extrapolated values
	integer nintp	!number of values to use (4 for cubic, 2 for linear)
	integer nmax	!length of data arrays
        real x(1),y(1)	!data arrays
	real xe		!x-value for which y-value has to be interpolated
	integer iact	!element closest to xe (of last call on entry)
			!must be 0 for initialization

	logical bdebug
	integer nanf,nend,i
	integer min,max
	real xlow,xhigh
	real ye

	real intp_neville

	bdebug = .true.
	bdebug = .false.

c----------------------------------------------------------
c start searching from first element in x
c----------------------------------------------------------

        if( iact .le. 0 ) iact=1

c----------------------------------------------------------
c find to xe closest x-value in vector x
c----------------------------------------------------------

	do while( iact .lt. nmax )
          xlow  = abs(x(iact)-xe)
          xhigh = abs(x(iact+1)-xe)
          if( xhigh .ge. xlow ) goto 1
          iact = iact + 1
	end do
    1   continue

c----------------------------------------------------------
c x(iact) is closest value to xe ...now get closest points around xe
c----------------------------------------------------------

	if( mod(nintp,2) .eq. 0 ) then	!even
		max = nintp / 2
		min = max - 1
	else
		max = nintp / 2
		min = max
	end if

        if( x(iact) .gt. xe ) then
                nanf=iact-max
                nend=iact+min
        else
                nanf=iact-min
                nend=iact+max
        end if

c----------------------------------------------------------
c handling for the beginning or the end of array x
c----------------------------------------------------------

        if( nanf .lt. 1 ) then
                nanf=1
                nend=nintp
        else if(nend.gt.nmax) then
                nanf=nmax-nintp+1
                nend=nmax
        end if

c----------------------------------------------------------
c interpolation
c----------------------------------------------------------

        ye=intp_neville(nintp,x(nanf),y(nanf),xe)

c----------------------------------------------------------
c debug
c----------------------------------------------------------

	if( bdebug ) then
	  write(6,*) '-------------------------------- debug exxpp'
	  write(6,*) iact,nanf,nend,nintp,nmax
	  write(6,*) (x(i),i=nanf,nend)
	  write(6,*) (y(i),i=nanf,nend)
	  write(6,*) xe,ye
	  write(6,*) '--------------------------------'
	end if

c----------------------------------------------------------
c in ye is interpolated value
c----------------------------------------------------------

        exxpp=ye
	
        end

c***************************************************************
c***************************************************************
c***************************************************************

	function rbilin(z,xdelta,ydelta,flag)

c bilinear interpolation in a square
c
c z 		vector containing the values at the nodes
c xdelta	relative x-coordinate (0...1) of interpolation point in square
c ydelta	   "     y-    "         "            "          "        "
c		...(e.g. : xdelta=0.5=ydelta is centre of square)
c flag		value at node that has not to be used for interpolation
c		...these values are extrapolated from the other nodes
c		...in case all 4 nodes equal to flag ==> rbilin = flag
c rbilin	interpolated value at return
c
c numeration of square
c			  (0,1)            (1,1)
c				+--------+
c				| 3    4 |
c				|        |
c				| 1    2 |
c				+--------+
c			  (0,0)            (1,0)
c
c diagonal sum = 5
c
c formula for interpolation :
c
c	z = a + b*x + c*y + d*x*y
c
c	a = z(0,0)
c	b = z(1,0) - z(0,0)
c	c = z(0,1) - z(0,0)
c	d = z(1,1) + z(0,0) - z(1,0) - z(0,1)

	implicit none

	real rbilin
	real z(4)
	real xdelta,ydelta
	real flag

	integer nout,nin,i,idiag,iih
	integer iout(4),iin(4)
	real zh(4),zhh,ztot
	real a,b,c,d

c----------------------------------------------------------------
c get inner nodes (with value) and outer nodes (without value)
c----------------------------------------------------------------

	nout=0
	nin=0
	ztot=0.
	do i=1,4
	  zhh = z(i)
	  zh(i) = zhh
	  if(zhh.eq.flag) then
		nout=nout+1
		iout(nout)=i
	  else
		nin=nin+1
		iin(nin)=i
		ztot=ztot+zhh
	  end if
	end do

c----------------------------------------------------------------
c extrapolate good (inner) to bad (outer) nodes
c----------------------------------------------------------------

	if(nout.eq.0) then	!no outer points
c		nothing
	else if(nin.eq.0) then	!no inner point
		rbilin=flag
		return
	else if(nin.eq.1) then	!only 1 inner point
		do i=1,4
		  zh(i)=ztot
		end do
	else if(nout.eq.1) then	!only 1 outer point
		iih=iout(1)
		idiag=5-iih
		zh(iih)=ztot-2.*zh(idiag)	!extrapolation from inner
						!...triangel to ext. point
	else			!2 inner/outer points
		if(iin(1)+iin(2).eq.5) then	!diagonal out of area
			zhh=ztot*0.5
			zh(iout(1))=zhh
			zh(iout(2))=zhh
		else				!side out of area
			iih=5-iin(2)		!to find point to be extrapol.
			zh(iih)=zh(iin(1))	!...get second inner point
			iih=5-iin(1)		!...and go to the diagonal
			zh(iih)=zh(iin(2))	!...
		end if
	end if

c----------------------------------------------------------------
c interpolation in square
c----------------------------------------------------------------

	a=zh(1)
	b=zh(2)-a
	c=zh(3)-a
	d=zh(4)-a-b-c

	rbilin = a + b*xdelta + c*ydelta + d*xdelta*ydelta

c----------------------------------------------------------------
c end of routine
c----------------------------------------------------------------

	end

c***************************************************************

	function rintq(z,idim,jdim,ipos,jpos,xdelta,ydelta,flag,ier)

c interpolation in a square
c
c z 		matrix containing the values at the nodes
c (idim,jdim)	dimension of z
c ipos,jpos	position of local node (0,0) in z
c xdelta	relative x-coordinate (0...1) of interpolation point in square
c ydelta	   "     y-    "         "            "          "        "
c		...(e.g. : xdelta=0.5=ydelta is centre of square)
c flag		value at node that has not to be used for interpolation
c		...these values are extrapolated from the other nodes
c		...in case all 4 nodes equal to flag ==> rintq = flag
c ier		error status (return value)
c		... 0 : ok
c		... 1 : coordinates have been adjusted because out of grid
c rintq		interpolated value at return
c
c uses rbilin to do bilinear interpolation in square
c
c numeration of square
c			  (0,1)            (1,1)
c				+--------+
c				| 3    4 |
c				|        |
c				| 1    2 |
c				+--------+
c			  (0,0)            (1,0)
c
c-----------------------------------------------------------------------

	implicit none

	real rintq
	integer idim,jdim
	integer ipos,jpos
	integer ier
	real xdelta,ydelta
	real flag
	real z(idim,jdim)

	integer i0,j0,i
	real xd,yd
	real zh(4)
	real rbilin

	integer iv(4),jv(4)
	data iv,jv /0,1,0,1,0,0,1,1/	!translates matrix into vector coord.

	i0=ipos
	j0=jpos
	xd=xdelta
	yd=ydelta

c----------------------------------------------------------------
c adjust coordinates out of grid
c----------------------------------------------------------------

	ier=0
	if(i0.lt.1) then
		ier=1
		i0=1
		xd=0.
	else if(i0.ge.idim) then
		ier=1
		i0=idim-1
		xd=1.
	end if
	if(j0.lt.1) then
		ier=1
		j0=1
		yd=0.
	else if(j0.ge.jdim) then
		ier=1
		j0=jdim-1
		yd=1.
	end if

c----------------------------------------------------------------
c copy values to array
c----------------------------------------------------------------

	do i=1,4
	  zh(i)=z(i0+iv(i),j0+jv(i))
	end do

c----------------------------------------------------------------
c bilinear interpolation
c----------------------------------------------------------------

	rintq = rbilin(zh,xd,yd,flag)

c----------------------------------------------------------------
c end of routine
c----------------------------------------------------------------

	end

c***************************************************************
c***************************************************************
c***************************************************************
c
c exffil	opens file and sets up array
c exffils	short version of exffil
c exffild	short version of exffil with default setting
c exfini	initializes array with file already open
c exfintp	interpolates value
c exfget	get last interpolated values
c exfgetvar	get last interpolated values (only for variable ivar)
c exfset	set values
c exfsetdef	set default values
c exfinfo	info on array
c
c exfunit
c exfnvar
c exfsize
c exfpres
c exfcheck
c
c all information needed is stored in vector array(*)
c
c called routines:
c
c exffil		exfini
c exffils		exffil
c exffild		exffils, 
c exfini		intp_ts
c exfintp		intp_ts
c exfget		-
c exfset		-
c exfinfo		-
c
c intp_ts		read_time_series, intp_neville, tcomp
c read_time_series	read_0_time_series, read_3_time_series
c
c used variable:
c
c       iunit           unit number of file
c       nintp           degree of interpolation (2 linear, 4 cubic)
c       nvar            number of variables
c       nsize           number of data per variable (may be 0 -> 1)
c	ndata		total data per time step (normally nvar)
c       ndim            dimension of array
c       nextra          extra information at beginning of array
c       ires            pointer into array to keep interpolated values
c       nspace          space needed to hold all information in array
c
c       rguard          guard value to check for out-of-bound access
c       
c if nsize = 0 or 1, then normal read, else 3D read
c
c iunit is 0 before initialization
c if file has been opened, iunit > 0, else iunit = -1
c
c formula for computing needed space:
c
c	nspace = 1 + nextra + (nintp+1) * (ndata+1)
c
c       1               guard value at end of array
c       nextra          extra header information
c       ndata+1         to keep variables (ndata) and time
c       nintp+1         to keep nintp time steps and one for result
c
c formula for computing pointer ires (pointer to results):
c
c       ires   = 1 + nextra + nintp * (ndata+1)
c
c filling of array:
c
c       header data				(nextra)
c	time_1,data_1				(1+ndata)
c	time_2,data_2				(1+ndata)
c	...
c	time_nintp,data_nintp			(1+ndata)
c	time_intp,data_intp			(1+ndata)
c       rguard					(1)
c
c header data is:
c
c	iunit,nintp,nvar,nsize,ndata,ndim,nextra,ires,nspace,rguard
c
c Usage: (easy)
c
c call exffils('ps.dat',ndim,array)	!opens and initializes
c ...
c call exfintp(array,t,value)		!interpolates for time t -> value(s)
c
c***************************************************************
c***************************************************************
c***************************************************************

        subroutine exffil(file,nintp,nvar,nsize,ndim,array)

c opens file and inititializes array
c
c everything needed is in array (unit, vars etc...)

        implicit none

        character*(*) file      !file name
	integer nintp		!grade of interpolation (2=linear,4=cubic)
	integer nvar		!how many vars (columns) to read/interpolate
        integer nsize           !number of data per variable (may be 0 -> 1)
        integer ndim            !dimension of array
        real array(ndim)        !array with all information

        integer iunit
        integer ifileo

        iunit = 0
	if( file .ne. ' ' ) then
          iunit = ifileo(iunit,file,'form','old')
          if( iunit .le. 0 ) goto 99
	end if

        call exfini(iunit,nintp,nvar,nsize,ndim,array)

	return
   99	continue
	write(6,*) 'file = ',file
	stop 'error stop exffil: cannot open file'
        end

c***************************************************************

        subroutine exffils(file,ndim,array)

c opens file and inititializes array - simplified version

	implicit none

        character*(*) file      !file name
        integer ndim            !dimension of array
        real array(ndim)        !array with all information

        integer nintp           !grade of interpolation (2=linear,4=cubic)
        integer nvar            !how many columns to read/interpolate
        integer nsize           !number of data per variable

	nintp=2
	nvar=1
        nsize=0

	call exffil(file,nintp,nvar,nsize,ndim,array)

	end

c***************************************************************

	subroutine exffild(file,ndim,array,default)

c opens file and inititializes array with default - simplified version

	implicit none

        character*(*) file      !file name
        integer ndim            !dimension of array
        real array(ndim)        !array with all information
        real default(1)         !default to use in case no file exists

        call exffils(file,ndim,array)
	call exfsetdef(array,default)

	end

c***************************************************************

	subroutine exfini(iunit,nintp,nvar,nsize,ndim,array)

c sets up interpolation from file -> all information is in array
c
c       space is computed as follows:
c
c       nvar variables + time -> nvar+1
c       nintp values per variable + interpolated values -> nintp+1
c       nextra is extra information heading the other data
c       one guard value at end of array

	implicit none

	integer iunit		!unit of file
	integer nintp		!grade of interpolation (2=linear, 4=cubic)
	integer nvar		!how many columns to read/interpolate
	integer nsize		!0 for normal read, else number of data/var
	integer ndim		!dimension of array, on return space used
	real array(ndim)	!array with information

        real rguard
        parameter(rguard=1.234543e+20)
	integer nextra
        parameter(nextra=10)

	logical b3d,debug
	integer ires,nspace,ndata,nnintp
        integer i
	real time
	character*80 file

	debug = .false.

c	-------------------------------------------------------------
c	set-up parameters
c	-------------------------------------------------------------

        nnintp = nintp
	if( iunit .le. 0 ) nnintp = 0   !reserve some space only for results

	b3d = nsize .gt. 1
	ndata = nvar * max(1,nsize)

        ires   = 1 + nextra + nnintp * (ndata+1)
	nspace = 1 + nextra + (nnintp+1) * (ndata+1)

c	-------------------------------------------------------------
c	check space and exit with error in case
c	-------------------------------------------------------------

	if( nspace .gt. ndim ) then
                write(6,*) '*** error in exfini'
		write(6,*) 'Space in array is not sufficient'
		write(6,*) 'dimension of array: ',ndim
		write(6,*) 'space needed:       ',nspace
		write(6,*) 'formula: 1 + nextra + (nnintp+1) * (ndata+1)'
		write(6,*) 'with nextra = ',nextra
		write(6,*) 'iunit,nnintp,nvar:  ',iunit,nnintp,nvar
		write(6,*) 'nsize,ndata:  ',nsize,ndata
		call filna(iunit,file)
		write(6,*) 'filename: ',file
		stop 'error stop exfini: ndim'
	end if

c	-------------------------------------------------------------
c	initialization of array, using result section as aux array
c	-------------------------------------------------------------

	if(debug) write(6,*) 'exfini: (initializing) ',iunit,nspace

        do i=1,nspace
          array(i) = 0.
        end do

	if( iunit .gt. 0 ) then
	  time = 0.     !is not used
	  call intp_ts(-iunit,nnintp,ndata,time,array(nextra+1)
     +			,array(ires+1),b3d)
        end if

	if(debug) then
	  write(6,*) 'exfini (end of intp_ts) : ',iunit,nintp,nnintp,nvar
	end if

c	-------------------------------------------------------------
c	write parameters to header of array
c	-------------------------------------------------------------

	array(1) = iunit
	array(2) = nnintp
	array(3) = nvar
	array(4) = nsize
	array(5) = ndata
	array(6) = ndim
	array(7) = nextra
	array(8) = ires
	array(9) = nspace
	array(10) = rguard
	array(nspace) = rguard

c	-------------------------------------------------------------
c	in case flag unit as not used
c	-------------------------------------------------------------

	if( iunit .eq. 0 ) array(1) = -1	!flag unit as not used

	if(debug) then
	  write(6,*) 'exfini: (finished initializing) ',iunit,nvar
	end if

c	-------------------------------------------------------------
c	end of routine
c	-------------------------------------------------------------

	end

c***************************************************************

	subroutine exfintp(array,t,rint)

c interpolation from file -> all information is in array
c
c interpolated values are in last part of array

	implicit none

	real array(*)		!array with information from set-up
	real t			!t value for which to interpolate
	real rint(1)		!interpolated values

	logical b3d
	integer iunit,nintp,nsize,ndata,nextra
        integer ires,nspace,i

	iunit  = nint(array(1))
	nintp  = nint(array(2))
	nsize  = nint(array(4))
	ndata  = nint(array(5))
	nextra = nint(array(7))
	ires   = nint(array(8))

	b3d = nsize .gt. 1

	if( iunit .gt. 0 ) then
	  call intp_ts(iunit,nintp,ndata,t,array(nextra+1),rint,b3d)
          array(ires) = t
          do i=1,ndata
            array(ires+i) = rint(i)
          end do
	else			!default data is already in place
          do i=1,ndata
            rint(i) = array(ires+i)
          end do
	end if

	call exfcheck(array)

	end

c***************************************************************

	subroutine exfget(array,t,rint)

c get last interpolated values (ndata values)

	implicit none

	real array(*)		!array with information from set-up
	real t			!t value for which to interpolate
	real rint(1)		!interpolated values

        integer ndata,ires,i

	ndata  = nint(array(5))
	ires   = nint(array(8))

        t = array(ires)
        do i=1,ndata
          rint(i) = array(ires+i)
        end do

	call exfcheck(array)

	end

c***************************************************************

	subroutine exfgetvar(array,ivar,t,rint)

c get last interpolated values (only for variable ivar, nsize values)

	implicit none

	real array(*)		!array with information from set-up
	integer ivar		!number of variable needed
	real t			!t value for which to interpolate
	real rint(1)		!interpolated values

        integer nvar,nsize
	integer ires,ip,i

	nvar   = nint(array(3))
	nsize  = max(nint(array(4)),1)
	ires   = nint(array(8))

	if( ivar .gt. nvar ) then
	  write(6,*) 'ivar = ',ivar,'   nvar = ',nvar
	  stop 'error stop exfgetvar: ivar too high'
	end if

        t = array(ires)
	ip = ires + (ivar-1)*nsize	!pointer to results of variable ivar
        do i=1,nsize
          rint(i) = array(ip+i)
        end do

	call exfcheck(array)

	end

c***************************************************************

	subroutine exfset(array,t,rint)

c sets new actual values

	implicit none

	real array(*)		!array with information from set-up
	real t			!t value for which to interpolate
	real rint(1)		!interpolated values

        integer ndata,ires,i

	ndata  = nint(array(5))
	ires   = nint(array(8))

        array(ires) = t
        do i=1,ndata
          array(ires+i) = rint(i)
        end do

	call exfcheck(array)

	end

c***************************************************************

	subroutine exfsetdef(array,rdef)

c sets default value (one for each variable)

	implicit none

	real array(*)		!array with information from set-up
	real rdef(1)		!default values for every variable

        integer nsize,nvar
	integer ires,i
	integer ivar,ip

	nvar   = nint(array(3))
	nsize  = max(nint(array(4)),1)
	ires   = nint(array(8))

        array(ires) = 0.	!time - not important
	do ivar=1,nvar
	  ip = ires + (ivar-1)*nsize	!pointer to results of variable ivar
          do i=1,nsize
            array(ip+i) = rdef(ivar)
	  end do
        end do

	call exfcheck(array)

	end

c***************************************************************

	subroutine exfinfo(ipunit,array)

c interpolation from file -> info

	implicit none

	integer ipunit		!unit where to print on (<0 -> 6)
	real array(*)		!array with information from set-up

	logical bdebug
	integer iunit,nintp,nvar,nsize,ndata,nextra,ndim
        integer ires,nspace
	integer ipu
	integer ip,in,i

	bdebug = .false.
	bdebug = .true.

	ipu = ipunit
	if( ipunit .le. 0 ) ipu = 6

	iunit  = nint(array(1))
	nintp  = nint(array(2))
	nvar   = nint(array(3))
	nsize  = nint(array(4))
	ndata  = nint(array(5))
	ndim   = nint(array(6))
	nextra = nint(array(7))
	ires   = nint(array(8))
	nspace = nint(array(9))

        write(ipu,*) 'info on array interpolation:'
        write(ipu,*) 'unit     : ',iunit
        write(ipu,*) 'nintp    : ',nintp
        write(ipu,*) 'nvar     : ',nvar
        write(ipu,*) 'nsize    : ',nsize
        write(ipu,*) 'ndata    : ',ndata
        write(ipu,*) 'ndim     : ',ndim
        write(ipu,*) 'nextra   : ',nextra
        write(ipu,*) 'ires     : ',ires
        write(ipu,*) 'nspace   : ',nspace
        write(ipu,*) 'rguard   : ',array(nspace)

	if( bdebug ) then
	  ip = 1 + nextra
	  do in=1,nintp
	    write(ipu,*) 'intp: level,pointer,time: ',in,ip,array(ip)
	    write(ipu,*) (array(ip+i),i=1,ndata)
	    ip = ip + ndata + 1
	  end do
	  write(ipu,*) 'result: level,pointer,time: ',0,ip,array(ip)
	  write(ipu,*) (array(ires+i),i=1,ndata)
	end if

        end

c***************************************************************

	subroutine exfunit(array,iunit)

c returns information on unit number

	implicit none

	real array(*)		!array with information from set-up
        integer iunit           !unit number of file, 0 if not initialized

	iunit = nint(array(1))

        end

c***************************************************************

	subroutine exfnvar(array,nvar)

c returns information on number of variables

	implicit none

	real array(*)		!array with information from set-up
        integer nvar            !total number of variables

	nvar = nint(array(3))

	end

c***************************************************************

	subroutine exfsize(array,nvar,nsize,ndata)

c returns information on size of data

	implicit none

	real array(11)		!array with information from set-up
        integer nvar            !total number of variables
        integer nsize           !data per variable
        integer ndata           !total data in array

	nvar  = nint(array(3))
	nsize = nint(array(4))
	ndata = nint(array(5))

        end

c***************************************************************

	subroutine exfpres(array,ires)

c returns pointer to interpolated result
c
c array(ires)	actual time of interpolated results
c array(ires+i)	actual interpolated result of variable i

	implicit none

	real array(11)		!array with information from set-up
        integer ires            !pointer to results in array

	ires   = nint(array(8))

        end

c***************************************************************

	subroutine exfcheck(array)

c checks array for guard values

	real array(*)

        real rguard
        parameter(rguard=1.234543e+20)

	integer nspace

	nextra = nint(array(7))
	nspace = nint(array(9))

        if( array(nextra) .ne. rguard ) then
            stop 'error stop exfintp: first guard value altered'
     	else if( array(nspace) .ne. rguard ) then
            stop 'error stop exfintp: last guard value altered'
        end if

	end

c***************************************************************
c***************************************************************
c***************************************************************
c***************************************************************
c***************************************************************

	subroutine exfsetdebug(debug)
	logical debug
	logical bdebug
	common /exfdebug/bdebug
	save /exfdebug/
	bdebug=debug
	end

	subroutine exfwritedebug(n,a)
	integer n
	real a(n)
	logical bdebug
	common /exfdebug/bdebug
	save /exfdebug/
	if( bdebug ) then
	  write(91,*) '------exfwritedebug------'
	  write(91,*) n,(a(i),i=1,n)
	  write(91,*) '-------------------------'
	end if
	end
	
c***************************************************************

