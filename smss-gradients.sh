#!/bin/bash

# Validate SMSS mode.
if [ -n ${SMSS_MODE} ] ; then
  if [ ${SMSS_MODE} -ne 1 -a ${SMSS_MODE} -ne 2 ] ; then
    echo "ERROR: smss-gradients.sh (SMSS_MODE)"
    exit 1
  fi
else
  echo "ERROR: smss-gradients.sh (SMSS_MODE)"
  exit 1
fi

# Get job directories.
SMSS_WDIR_BASE=${PWD}
SMSS_WDIR_TURBO=${SMSS_WDIR_BASE}/TurboJdir
SMSS_WDIR_VASP=${SMSS_WDIR_BASE}/VaspJdir
if [ ${SMSS_MODE} -eq 1 ] ; then
  SMSS_WDIR_COSMO=${SMSS_WDIR_BASE}/CosmoJdir
  if [ -d ${SMSS_WDIR_COSMO} -a ! -d ${SMSS_WDIR_TURBO} ] ; then
    SMSS_WDIR_TURBO=${SMSS_WDIR_BASE}
  elif [ -d ${SMSS_WDIR_TURBO} -a ! -d ${SMSS_WDIR_COSMO} ] ; then
    SMSS_WDIR_COSMO=${SMSS_WDIR_BASE}
  else
    echo "ERROR: smss-gradients.sh (SMSS_WDIR_*)"
    exit 1
  fi
elif [ ${SMSS_MODE} -eq 2 ] ; then
  SMSS_WDIR_DLPOLY=${SMSS_WDIR_BASE}/DlpolyJdir
  SMSS_WDIR_PEECM=${SMSS_WDIR_BASE}/PeecmJdir
  SMSS_WDIR_REFIMG=${SMSS_WDIR_BASE}/RefimgJdir
  if [ -d ${SMSS_WDIR_PEECM} -a ! -d ${SMSS_WDIR_TURBO} ] ; then
    SMSS_WDIR_TURBO=${SMSS_WDIR_BASE}
  elif [ -d ${SMSS_WDIR_TURBO} -a ! -d ${SMSS_WDIR_PEECM} ] ; then
    SMSS_WDIR_PEECM=${SMSS_WDIR_BASE}
  else
    echo "ERROR: smss-gradients.sh (SMSS_WDIR_*)"
    exit 1
  fi
else
  echo "ERROR: smss-gradients.sh (SMSS_MODE)"
  exit 1
fi

# Check RI option.
cd ${SMSS_WDIR_BASE}
SMSS_RIJ=`grep '^\$rij$' control | wc -l`
if [ ${SMSS_RIJ} -eq 0 ] ; then
  SMSS_EXEC_TURBO="grad"
elif [ ${SMSS_RIJ} -eq 1 ] ; then
  SMSS_EXEC_TURBO="rdgrad"
else
  echo "ERROR: smss-gradients.sh (SMSS_RIJ)"
  exit 1
fi


# Execute TURBOMOLE jobs.
if [ ${SMSS_MODE} -eq 1 ] ; then
  cd ${SMSS_WDIR_TURBO}
  unset OMP_PROC_BIND
  unset OMP_PLACES
  unset OMP_NUM_THREADS
  ${SMSS_EXEC_TURBO}.save > ${SMSS_EXEC_TURBO}.out 
  wait
  cd ${SMSS_WDIR_COSMO}
  ${SMSS_EXEC_TURBO}.save > ${SMSS_EXEC_TURBO}.out 
  wait
elif [ ${SMSS_MODE} -eq 2 ] ; then
  cd ${SMSS_WDIR_PEECM}
  unset OMP_PROC_BIND
  unset OMP_PLACES
  unset OMP_NUM_THREADS
  ${SMSS_EXEC_TURBO}.save > ${SMSS_EXEC_TURBO}.out 
  wait
  cd ${SMSS_WDIR_TURBO}
  ${SMSS_EXEC_TURBO}.save > ${SMSS_EXEC_TURBO}.out 
  wait
fi
################################### Modification By Mehdi Zare for Mean Field Gradient Calculations ##################################

# Perform fortran code to get the meanfield average of gradients for reference image 
  cd ${SMSS_WDIR_REFIMG}
  rm -f GradAVERAGE
  SMSS_EXEC_MEANFIELD=`echo "GradMeanField"`
  ${SMSS_EXEC_MEANFIELD}
# this will create a file named " GradAVERAGE " that Faheem's code will read the mean fieald avearages from there

###################################			 End of Modification 			     #################################


# Clean up temporary files.
cd ${SMSS_WDIR_BASE}

