      subroutine int_mom_sifs(ibas, oskel, aoints, nbft, 
     &  l1rec, n1max, 
     &  sifbuf, sifval, ninfo, info, fcore, ibvtyp, ibitv,
     &  SOval, cSOlab)
      USE nwc_sym, ONLY: mxsym,mxbf
      implicit none
#include "errquit.fh"
#include "cint1cache.fh"
#include "mafdecls.fh"
#include "global.fh"
#include "rtdb.fh"
#include "inp.fh"
#include "apiP.fh"
#include "bas.fh"
#include "cscfps.fh"
#include "sym.fh"
#include "geom.fh"
c     
c     Oskel indicates that the skeleton (petite-list symmetry) matrix should be
c     built ... 
c     
c     arguments
c     
      integer ibas
      logical oskel             ! [input] If true generate symmetry unique list
      double precision sifval(n1max)
      double precision sifbuf(l1rec)
      integer ninfo
      integer info(ninfo)  ! not to be confused with NWChem info
      integer clab(2,n1max)
      integer cSOlab(2,n1max)
      real*8 fcore

c     
c     local variables
c     
      integer nshell
      integer ishell, jshell, mem1, max1e, lrecal, n1mx, maxint
      integer ilo, ihi, jlo, jhi, max1mom, mem1mom
      integer l_buf, l_scr, 
     &        l_momx, l_momy, l_momz, l_imom, l_jmom,
     &        l_dipx, l_dipy, l_dipz
      integer k_buf, k_scr,
     &        k_momx, k_momy, k_momz, k_imom, k_jmom,
     &        k_dipx, k_dipy, k_dipz
      integer noffsetx, noffsety, noffsetz
      logical odoit
      double precision q2
      external block_int1e      ! For T3D
      integer i, noffset,g_loc, j, ijmap, symmap, symints
c
      logical ocache_save
c
      logical odbug
      logical osome
      character*8 blabtmp
      integer nbft
C LB
      integer lval                !Order  of dipole integrals
      double precision centerl(3) !Center of dipole integrals
      integer num_MPint           !Number of dipole integrals
      integer geom
C LB
c  
c     sifs parameters
c
      integer aoints, ierr
      integer l1rec, n1max
      integer ibvtyp
      integer ibitv
!      integer mxbf
c     make sure this is compatible with columbus
!      parameter (mxbf=1000)
c     header 1
      integer ntitle, nsym, nbas, mxenrgy
!      parameter(ntitle=1,nsym=1,mxenrgy=1)
      parameter(ntitle=1,mxenrgy=1)
c     header 2
      integer otype, nprim, ngen, sphcart, iat, shdim, igen, ibf
      integer numtot
      integer msame,nmsame,nomore
      parameter(msame=0, nmsame=1, nomore= 2)
      integer nrec
      integer itypea, itypeb, last, num
      integer  ibuf
      logical basok
      real*8 momval
      CHARACTER(10) integ_type
      

cgk provisional
*     change thresh to the appropriate user supplied zero tolerance
      real*8 thresh
      parameter (thresh=1d-12)
cgk end
      integer numints, icart, kcart, int_type
C LB
      INTEGER :: nsoints ! number of symmetry orbital integrals
      DOUBLE PRECISION :: SOval(n1max)
C LB
      
c
cgk debug
       write(*,*)'gk: **** entered int_mom_sifs'
cgk end
      basok=.false.
      odbug=.true.
      osome=.true.
      osome=osome.or.odbug
      odbug=odbug.and.(ga_nodeid().eq.0)
      osome=osome.and.(ga_nodeid().eq.0)
c
      call ga_sync()
      if (oscfps) call pstat_on(ps_int_1e)
c     
c     Get info about the basis sets
c     
      if (.not. bas_numcont(ibas, nshell)) call errquit
     $     ('int_mom_sifs: bas_numcont failed for ibas', ibas,
     &       BASIS_ERR)
      if (nbft.gt.mxbf) call errquit
     $     ('int_mom_sifs: nbft gt maximum aoints basis functions', 
     &       nbft, BASIS_ERR)
c     
c     allocate necessary local temporary arrays on the stack
c     
c     l_buf ... buffer to hold shell block of matrix
c     l_s   ... buffer to hold shell block of matrix
c     l_scr ... workspace for integral routines
c     
c     k_* are the offsets corrsponding to the l_* handles
c     
cgk debug
*      write(*,*)'gk: max1e=', max1e
*      write(*,*)'gk: mem1=', mem1
*      write(*,*)'gk: nbft=', nbft
cgk end
      call int_init_dip(max1e,mem1,ibas)
      max1mom=3*max1e
      mem1mom=3*mem1
      mem1mom=max(mem1mom,max1mom)
      mem1mom=6*3*mem1mom !mem1mom was insufficient for int_mpolel
      maxint=nbft*nbft 
cgk debug
      !write(*,*)'gk: max1mom=', max1mom
      !write(*,*)'gk: mem1mom=', mem1mom
      !write(*,*)'gk: maxint=', maxint
cgk end

c     get memory for integral buffer
      if (.not. MA_push_get(MT_DBL,max1mom,'int_mom_sifs:buf',l_buf,
     &  k_buf))
     $     call errquit('int_mom_sifs: ma failed', max1mom, MA_ERR)
c     get memory for scratch space
      if (.not. MA_push_get(MT_DBL, mem1mom,'int_mom_sifs:scr',l_scr,
     &  k_scr))
     $     call errquit('int_mom_sifs: ma failed', mem1mom, MA_ERR)
c     get memory for x 
      if (.not. MA_push_get(MT_DBL,maxint,'int_mom_sifs:momx',l_momx,
     &        k_momx))
     $     call errquit('int_mom_sifs: ma failed for mom x', maxint, 
     &        MA_ERR)
c     get memory for y 
      if (.not. MA_push_get(MT_DBL,maxint,'int_mom_sifs:momy',l_momy,
     &        k_momy))
     $     call errquit('int_mom_sifs: ma failed for mom y', maxint, 
     &        MA_ERR)
c     get memory for z 
      if (.not. MA_push_get(MT_DBL,maxint,'int_mom_sifs:momz',l_momz,
     &        k_momz))
     $     call errquit('int_mom_sifs: ma failed for mom z', maxint, 
     &        MA_ERR)
c     get memory for full bra label array
      if (.not. MA_push_get(MT_Int,maxint,'int_mom_sifs:imom',l_imom,
     &        k_imom))
     $     call errquit('int_mom_sifs: ma failed for imom', maxint, 
     &        MA_ERR)
c     get memory for full ket label array
      if (.not. MA_push_get(MT_Int,maxint,'int_mom_sifs:jmom',l_jmom,
     &        k_jmom))
     $     call errquit('int_mom_sifs: ma failed for jmom', maxint, 
     &        MA_ERR)
C LB For dipoles
c     get memory for x dipole
      if (.not. MA_push_get(MT_DBL,maxint,'int_mom_sifs:dipx',l_dipx,
     &        k_dipx))
     $     call errquit('int_mom_sifs: ma failed for dip x', maxint, 
     &        MA_ERR)
c     get memory for y dipole
      if (.not. MA_push_get(MT_DBL,maxint,'int_mom_sifs:dipy',l_dipy,
     &        k_dipy))
     $     call errquit('int_mom_sifs: ma failed for dip y', maxint, 
     &        MA_ERR)
c     get memory for z dipole
      if (.not. MA_push_get(MT_DBL,maxint,'int_mom_sifs:dipz',l_dipz,
     &        k_dipx))
     $     call errquit('int_mom_sifs: ma failed for dip z', maxint, 
     &        MA_ERR)
C LB

c     start loop over integral types here
c       int_type = 0, spin-orbit potential
c       int_type = 1, linear momentum
c       int_type = 2, angular momentum
c       int_type = 3, dipole moments
      do int_type=1,3
!        WRITE(*,*)"LB, starting int_type loop",int_type

        if(int_type.eq.1.or.int_type.eq.2) itypea=2 ! gonna do dipole
        if(int_type.eq.3) itypea=1

!        WRITE(*,*)"  LB, starting int_type loop, itypea=",itypea

        if (0 .eq. ga_nodeid()) then
cgk debug
       !write(*,*)'gk: int_type = ', int_type
cgk end

c          start loop over integrals here.
           numints=0
           do jshell = 1, nshell
              do ishell = 1, nshell
cgk debug
      write(*,'(a,i4,a,i4)')'gk: ishell=',ishell,' jshell=',jshell
cgk end
                 odoit = .true.
                 if (oskel) 
     $              odoit = sym_shell_pair(ibas, ishell, jshell, q2)
 
                 if (odoit) then
                    if (.not. bas_cn2bfr(ibas, ishell, ilo, ihi)) 
     $                call errquit('int_1e_ga: bas_cn2bfr ishell', 
     &                    ishell, BASIS_ERR)
                    if (.not. bas_cn2bfr(ibas, jshell, jlo, jhi)) 
     $                call errquit('int_1e_ga: bas_cn2bfr jshell', 
     &                    jshell, BASIS_ERR)

                    if(int_type.eq.1) then
cgk debug
       !write(*,*)'gk: calling int_veloc'
cgk end
C LB
!                      call int_veloc (ibas, jshell, ibas, ishell, 
!     $                   mem1mom, dbl_mb(k_scr), max1mom, dbl_mb(k_buf))
                      call int_veloc (ibas, ishell, ibas, jshell, 
     $                   mem1mom, dbl_mb(k_scr), max1mom, dbl_mb(k_buf))
                    elseif(int_type.eq.2) then
C LB
cgk debug
       !write(*,*)'gk: calling int_angmom'
cgk end
C LB
!                      call int_angmom (ibas, jshell, ibas, ishell, 
!     $                   mem1mom, dbl_mb(k_scr), max1mom, dbl_mb(k_buf))
                      call int_angmom (ibas, ishell, ibas, jshell, 
     $                   mem1mom, dbl_mb(k_scr), max1mom, dbl_mb(k_buf))
C LB
C LB Dipoles
                    elseif(int_type.eq.3) then
                      lval=1;! 1 for dipoles
                      ! get geom
                      IF (.NOT. bas_geom(ibas,geom)) CALL errquit
     $                  ('int_mom_sifs: bas_geom failed for ibas', ibas,
     &                  BASIS_ERR)
                      ! get centerl
!                      IF (.NOT. geom_center_of_mass(geom, centerl)) CALL
!     &               errquit ('int_mom_sifs: geom_center_of_mass failed'
!     &               ,geom,GEOM_ERR)
                      centerl=0
!        WRITE(*,*)"LB, calling int_mpolel"                      
        WRITE(*,*)"LB, centerl=",centerl                      
                      CALL int_mpolel (ibas, ishell, ibas, jshell,
     $                   lval, centerl, 
     $                   mem1mom, dbl_mb(k_scr), max1mom, dbl_mb(k_buf),
     $                   Num_MPint)
!       WRITE(*,'(a,2i5)')"LB, ishell, jshell =", ishell, jshell
!       WRITE(*,'(a,1i5)')"LB, Num_MPint =", Num_MPint
!       WRITE(*,*)"poles="
!       WRITE(*,*)dbl_mb(k_buf:k_buf+Num_MPint-1)
C LB                      
                    endif

                    IF (int_type .lt. 3) THEN
                      noffsetz = 0
                      noffsety = (ihi-ilo+1)*(jhi-jlo+1)
                      noffsetx = (ihi-ilo+1)*(jhi-jlo+1)*2
                    ELSE ! dipoles
                      noffsetz = 0
                      noffsety = 1
                      noffsetx = 2
                    ENDIF

!       WRITE(*,'(a,3i4)')"LB, noffsetz,noffsety,noffsetx=",noffsetz,
!     &                  noffsety,noffsetx
                    do j=jlo,jhi
                      do i=ilo,ihi
cgk debug
      write(*,'(a,i4,a,i4,a,i4,a,i4)')
     &  'gk: ilo=',ilo,' ihi=',ihi,' jlo=',jlo,' jhi=',jhi
      write(*,*)'gk: numints=',numints
cgk end
                         ijmap=(j-jlo)*(ihi-ilo+1)+(i-ilo)
                         IF (int_type .eq. 3) THEN! dipoles
                           ijmap=(i-ilo)*(jhi-jlo+1)+(j-jlo)
                           ijmap=ijmap*3
                         ENDIF
                         if(i.ge.j) then
                           symmap=nbft*(j-1)-((j-1)*j)/2+i
!      WRITE(*,'(a,2i4)')"LB, ijmap, symmap=",ijmap,symmap
!      write(*,*)'gk: symmap=',symmap
                           dbl_mb(k_momx+symmap-1)=
     &                       dbl_mb(k_buf+noffsetx+ijmap)
                           dbl_mb(k_momy+symmap-1)=
     &                       dbl_mb(k_buf+noffsety+ijmap)
                           dbl_mb(k_momz+symmap-1)=
     &                       dbl_mb(k_buf+noffsetz+ijmap)
                           int_mb(k_imom+symmap-1)=i
                           int_mb(k_jmom+symmap-1)=j
cgk debug
!                       write(*,'(a,3i3,f18.12)')
!     &                   'gk:  i,j,ij,dbl_mb(mom_x):',
!     &                    i,j,numints+ijmap,dbl_mb(k_momx+symmap-1)
!                       write(*,'(a,3i3,f18.12)')
!     &                   'gk:  i,j,ij,dbl_mb(mom_y):',
!     &                    i,j,numints+ijmap,dbl_mb(k_momy+symmap-1)
!                       write(*,'(a,3i3,f18.12)')
!     &                   'gk:  i,j,ij,dbl_mb(mom_z):',
!     &                    i,j,numints+ijmap,dbl_mb(k_momz+symmap-1)
cgk end
                         endif
                      enddo ! ilo
                    enddo ! jlo
                    numints=numints+ijmap+1
                 end if
             end do ! i shell
           end do ! j shell
c call sifs
        endif
        call ga_sync()            ! So that no nasty races can result
cgk debug
*       write(*,*)'gk: numints = ', numints
*       write(*,*)'gk: maxint = ', maxint
*       symmap=0
*       do i=1,nbft
*         do j = 1, i
*           write(*,'(a,2i8,3f18.12)')
*    &      'gk:  i,j,so_x,so_y,so_z:', int_mb(k_imom+symmap),
*    &      int_mb(k_jmom+symmap),dbl_mb(k_momx+symmap), 
*    &      dbl_mb(k_momy+symmap), dbl_mb(k_momz+symmap)
*           symmap=symmap+1
*         enddo
*       enddo
        do icart = 1, 3
          !WRITE(*,*)"LB, icart=",icart
          if(icart.eq.1) then
            kcart=k_momz
            itypeb=0+mod(int_type,3)*3
            IF(int_type.eq.1) THEN
              !integ_type='linmomz'
              integ_type='linmomx'
            ELSE IF(int_type.eq.2) THEN
              !integ_type='angmomz'
              integ_type='angmomx'
            ELSE 
              integ_type='dipmomx'
            ENDIF
          elseif(icart.eq.2) then
            kcart=k_momy
            itypeb=1+mod(int_type,3)*3
            IF(int_type.eq.1) THEN
              integ_type='linmomy'
            ELSE IF (int_type.eq.2) THEN
              integ_type='angmomy'
            ELSE
              integ_type='dipmomy'
            ENDIF
          elseif(icart.eq.3) then
            kcart=k_momx
            itypeb=2+mod(int_type,3)*3
            IF(int_type.eq.1) THEN
              !integ_type='linmomx'
              integ_type='linmomz'
            ELSE IF(int_type.eq.2) THEN 
              !integ_type='angmomx'
              integ_type='angmomz'
            ELSE
              integ_type='dipmomz'
            ENDIF
          endif
          symmap=0
          numtot=0
          ibuf=0
          do i=1,nbft
            do j = 1, i
              if(ibuf.eq.n1max) then
                numtot = numtot + ibuf
C LB
         !WRITE(*,*)"LB: in int_mom_sifs"
!         WRITE(*,*)"LB: in int_mom_sifs, ibuf=",ibuf
!         WRITE(*,*)"LB: itypea,itypeb=",itypea,itypeb
         !WRITE(*,*)"LB: calling sifew1 1 last=",last,"ibvtyp=",ibvtyp
C LB
                call sifew1(aoints, info, 2, ibuf, msame, 
     &            itypea, itypeb, ibvtyp, 
     &            sifval, clab, fcore, ibitv, 
     &            sifbuf, nrec, ierr)
                numtot = numtot - ibuf
              endif

              momval=dbl_mb(kcart+symmap)
            
!            WRITE(*,*)"LB, momval =",momval
              if(abs(momval).gt.thresh) then
                 ibuf=ibuf+1
                 clab(1,ibuf)=int_mb(k_imom+symmap)
                 clab(2,ibuf)=int_mb(k_jmom+symmap)
                 sifval(ibuf)=momval
              endif
              symmap=symmap+1
            enddo
          enddo
          if (icart.eq.3.and.int_type.eq.3) then
            last=nomore 
          else
            last=nmsame
          endif
          numtot=numtot+ibuf
cgk debug
*     write(*,*)'gk: nrec=', nrec
*     write(*,*)'gk:  ibuf=', ibuf
*     write(*,*)'gk:  numtot=', numtot
cgk end
C LB
!         WRITE(*,*)"LB: in int_mom_sifs, ibuf=",ibuf
!         WRITE(*,*)"LB: itypea,itypeb=",itypea,itypeb
!         WRITE(*,*)"C LB, calling sym_1int 2"
!         CALL sym_1int(ibuf,nsoints,
!     &                 sifval, clab,
!     &                 SOval, cSOlab)
!         WRITE(*,*)"LB: calling sifew1 2 last=",last,"ibvtyp=",ibvtyp
C LB
!          call sifew1(aoints, info, 2, nsoints, last, 
          call sifew1(aoints, info, 2, ibuf, last, 
     &      itypea, itypeb, ibvtyp, 
!     &      SOval, cSOlab, fcore, ibitv, 
     &      sifval, clab, fcore, ibitv, 
     &      sifbuf, nrec, ierr)
        write(6,'(a,i10,1x,a,a)') 'Wrote ',numtot, integ_type, 
     &     ' integrals to aoints'
        enddo !icart
        !!WRITE(*,*)"LB, done with icart loop"
      enddo
cgk end
cgk debug
*     write(*,*)'gk:  l_jmom = ', l_jmom
*     write(*,*)'gk:  k_jmom = ', k_jmom
cgk end
c     
c     chop stack at first item allocated
c     
C LB dipoles
      if (.not. MA_pop_stack(l_dipz)) call errquit
     $     ('int_mom_sifs: pop failed at l_dipz', 0, GA_ERR)
      if (.not. MA_pop_stack(l_dipy)) call errquit
     $     ('int_mom_sifs: pop failed at l_dipy', 0, GA_ERR)
      if (.not. MA_pop_stack(l_dipx)) call errquit
     $     ('int_mom_sifs: pop failed at l_dipx', 0, GA_ERR)
C LB
      if (.not. MA_pop_stack(l_jmom)) call errquit
     $     ('int_mom_sifs: pop failed at l_jmom', 0, GA_ERR)
      if (.not. MA_pop_stack(l_imom)) call errquit
     $     ('int_mom_sifs: pop failed at l_imom', 0, GA_ERR)
      if (.not. MA_pop_stack(l_momz)) call errquit
     $     ('int_mom_sifs: pop failed at l_momz', 0, GA_ERR)
      if (.not. MA_pop_stack(l_momy)) call errquit
     $     ('int_mom_sifs: pop failed at l_momy', 0, GA_ERR)
      if (.not. MA_pop_stack(l_momx)) call errquit
     $     ('int_mom_sifs: pop failed at l_momx', 0, GA_ERR)
      if (.not. MA_pop_stack(l_scr)) call errquit
     $     ('int_mom_sifs: pop failed at l_scr', 0, GA_ERR)
      if (.not. MA_pop_stack(l_buf)) call errquit
     $     ('int_mom_sifs: pop failed at l_buf', 0, GA_ERR)
 
      call ga_sync()            ! So that no nasty races can result
      
      if (oscfps) call pstat_off(ps_int_1e)
c     
cgk debug
*     write(*,*)'gk: leaving int_so_sifs at end of routine'
cgk end
      end
