#!/usr/bin/env bash
if [ $# -eq 0 ]
  then
    echo "NWCHEM_TOP arg missing"
    exit 1
fi
if [ ! -f $1/src/mpi_lib.txt ]; then
    $1/src/tools/guess-mpidefs --mpi_lib > $1/src/mpi_lib.txt
fi
cat  $1/src/mpi_lib.txt 
