program test_netcdf_fortran
  use netcdf
  implicit none
  integer :: ncid, status
  status = nf90_create("test_output.nc", NF90_CLOBBER, ncid)
  if (status /= NF90_NOERR) then
    print *, "ERROR: nf90_create failed: ", nf90_strerror(status)
    stop 1
  end if
  status = nf90_close(ncid)
  print *, "NetCDF-Fortran verification: OK"
end program