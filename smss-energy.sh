#!/bin/bash


# Validate SMSS mode.
if [ -n ${SMSS_MODE} ] ; then
  if [ ${SMSS_MODE} -ne 1 -a ${SMSS_MODE} -ne 2 ] ; then
    echo "ERROR: smss-energy.sh (SMSS_MODE)"
    exit 1
  fi
else
  echo "ERROR: smss-energy.sh (SMSS_MODE)"
  exit 1
fi

# Get job directories.
SMSS_WDIR_BASE=${PWD}
SMSS_WDIR_TURBO=${SMSS_WDIR_BASE}/TurboJdir
SMSS_WDIR_VASP=${SMSS_WDIR_BASE}/VaspJdir
SMSS_IDIR_BASE=`grep -m 1 IDIR_BASE SMSS_INPUT | awk '{print $3}'`
if [ ${SMSS_MODE} -eq 1 ] ; then
  SMSS_WDIR_COSMO=${SMSS_WDIR_BASE}/CosmoJdir
  if [ -d ${SMSS_WDIR_COSMO} -a ! -d ${SMSS_WDIR_TURBO} ] ; then
    SMSS_WDIR_TURBO=${SMSS_WDIR_BASE}
  elif [ -d ${SMSS_WDIR_TURBO} -a ! -d ${SMSS_WDIR_COSMO} ] ; then
    SMSS_WDIR_COSMO=${SMSS_WDIR_BASE}
  else
    echo "ERROR: smss-energy.sh (SMSS_WDIR_*)"
    exit 1
  fi
elif [ ${SMSS_MODE} -eq 2 ] ; then
  SMSS_WDIR_DLPOLY=${SMSS_WDIR_BASE}/DlpolyJdir
  SMSS_WDIR_PEECM=${SMSS_WDIR_BASE}/PeecmJdir
  SMSS_WDIR_REFIMG=${SMSS_WDIR_BASE}/RefimgJdir
  SMSS_IDIR_DLPOLY=${SMSS_IDIR_BASE}/DlpolySdir
  if [ -d ${SMSS_WDIR_PEECM} -a ! -d ${SMSS_WDIR_TURBO} ] ; then
    SMSS_WDIR_TURBO=${SMSS_WDIR_BASE}
  elif [ -d ${SMSS_WDIR_TURBO} -a ! -d ${SMSS_WDIR_PEECM} ] ; then
    SMSS_WDIR_PEECM=${SMSS_WDIR_BASE}
  else
    echo "ERROR: smss-energy.sh (SMSS_WDIR_*)"
    exit 1
  fi
else
  echo "ERROR: smss-energy.sh (SMSS_MODE)"
  exit 1
fi

# Check RI option.
cd ${SMSS_WDIR_BASE}
SMSS_RIJ=`grep '^\$rij$' control | wc -l`
if [ ${SMSS_RIJ} -eq 0 ] ; then
  SMSS_EXEC_TURBO="dscf"
elif [ ${SMSS_RIJ} -eq 1 ] ; then
  SMSS_EXEC_TURBO="ridft"
else
  echo "ERROR: smss-energy.sh (SMSS_RIJ)"
  exit 1
fi

# Execute TURBOMOLE and VASP jobs.
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
  cd ${SMSS_WDIR_VASP}
  export OMP_PROC_BIND=true
  export OMP_PLACES=threads
  export OMP_NUM_THREADS=28
  mpirun -np 28  /home/mzare/VASP_5.4.4/vasp.5.4.4/bin/vasp_std 1> RESULTS 2> ERROR 
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
  cd ${SMSS_WDIR_VASP}
  export OMP_PROC_BIND=true
  export OMP_PLACES=threads
  export OMP_NUM_THREADS=28
  mpirun -np 28  /home/mzare/VASP_5.4.4/vasp.5.4.4/bin/vasp_std 1> RESULTS 2> ERROR
  wait
fi
#clean up the node on hyperion for Turbomole jobs
################################################
find /dev/shm -user mzare -exec rm -fr {} \;
################################################

####################################   MODIFICATION BY MEHDI ZARE ##################################

# Execute DLPOLY jobs.

if [ ${SMSS_MODE} -eq 2 ] ; then
  # Execute REFERENCE job.
  cd ${SMSS_WDIR_REFIMG}
  rm -f MMS_REPLAY*
  
  # create Ref100 and Dlpoly100 directories
  # in FEP we created them in job-sctipt
  rm -rf Ref100 Dlpoly100
  mkdir Ref100 Dlpoly100 

# Preparing Ref100 directory
  cp -f ${SMSS_WDIR_REFIMG}/{CONFIG,CONTROL,FIELD,HISTORY,MMS_ENSEMBLE} ${SMSS_WDIR_REFIMG}/Ref100/
  cd ${SMSS_WDIR_REFIMG}/Ref100
  rm -f MMS_REPLAY*
  export OMP_NUM_THREADS=16
  SMSS_EXEC_DLPOLY=`echo "dlpoly-replay-history"`
  ${SMSS_EXEC_DLPOLY}
  sleep 2m

# Checking for completion
  ref100_success=`wc -l stderr | awk -F " " '{print $1}'`
  while [ $ref100_success -ne 0 ]
  do rm -f MMS_REPLAY*
  export OMP_NUM_THREADS=16
  SMSS_EXEC_DLPOLY=`echo "dlpoly-replay-history"`
  ${SMSS_EXEC_DLPOLY}
  sleep 2m
  ref100_success=`wc -l stderr | awk -F " " '{print $1}'`
  done

  cp MMS_REPLAY ../MMS_REPLAY_Refimg_100

# Prepare Dlpoly100 directory
  cp -f ${SMSS_WDIR_DLPOLY}/{CONFIG,CONTROL,FIELD_TEMPLATE,MMS_ENSEMBLE} ${SMSS_WDIR_REFIMG}/Dlpoly100/
  cp -f ${SMSS_WDIR_REFIMG}/HISTORY ${SMSS_WDIR_REFIMG}/Dlpoly100/
  cd ${SMSS_WDIR_REFIMG}/Dlpoly100
  SMSS_EXEC_DLPOLY=`echo "dlpoly-replace-field-charges -c ${SMSS_WDIR_PEECM}/coord -o ${SMSS_WDIR_PEECM}/${SMSS_EXEC_TURBO}.out -m NATURAL"`
  ${SMSS_EXEC_DLPOLY}
  rm -f MMS_REPLAY*
  export OMP_NUM_THREADS=16
  SMSS_EXEC_DLPOLY=`echo "dlpoly-replay-history"`
  ${SMSS_EXEC_DLPOLY}
  sleep 2m

# Checking for completion
  dl100_success=`wc -l stderr | awk -F " " '{print $1}'`
  while [ $dl100_success -ne 0 ]
  do rm -f MMS_REPLAY*
  export OMP_NUM_THREADS=16
  SMSS_EXEC_DLPOLY=`echo "dlpoly-replay-history"`
  ${SMSS_EXEC_DLPOLY}
  sleep 2m
  dl100_success=`wc -l stderr | awk -F " " '{print $1}'`
  done


  cp MMS_REPLAY ../MMS_REPLAY_Dlpoly_100

# Perform fortran code to get the meanfield average   
  cd ${SMSS_WDIR_REFIMG}
  rm -f AVERAGE MMS_REPLAY_AVERAGE
  SMSS_EXEC_MEANFIELD=`echo "MeanField"`
  ${SMSS_EXEC_MEANFIELD}

# Get the fixed value
  Ave=`head AVERAGE | tail -1 | awk '{print $1}'`

# make MMS_REPLAY format for the first frame and replace the energy value wih "Ave" to make it easier for Faheem code to read it
  linenum=`wc -l MMS_ENSEMBLE | awk '{ print $1  }'`
  oneframe=$(($linenum+3))                                              # total number of lines in one-fram-MMS_REPLAY
  head -n$oneframe MMS_REPLAY_Refimg_100 > MMS_REPLAY_AVERAGE
  energyold=`head -3 MMS_REPLAY_AVERAGE | tail -1 | awk '{ print $3  }'`
  sed -i "s/$energyold/$Ave/" MMS_REPLAY_AVERAGE

##################################  END OF MODIFICATION BY MEHDI ZARE ##################################

  # Prepare REPLAY jobs.
  cd ${SMSS_WDIR_DLPOLY}
  cp -f ${SMSS_IDIR_DLPOLY}/HISTORY.* .
  SMSS_PARJOBS_HISTORY=`ls -l HISTORY.* | wc -l`
  if [ ${SMSS_PARJOBS_HISTORY} -lt 1 ] ; then
    echo "ERROR: smss-energy.sh (HISTORY.*)"
    exit 1
  fi
  rm -f MMS_ENERGY MMS_GRADIENTS MMS_STEP job-*/MMS_ENSEMBLE job-*/MMS_REPLAY
  SMSS_EXEC_DLPOLY=`echo "dlpoly-replace-field-charges -c ${SMSS_WDIR_PEECM}/coord -o ${SMSS_WDIR_PEECM}/${SMSS_EXEC_TURBO}.out -m NATURAL"`
  ${SMSS_EXEC_DLPOLY}
#  cp -f ${SLURM_SUBMIT_DIR}/numforce/DlpolyJdir/MMS_REF_ENERGY .
#  cp -f ${SLURM_SUBMIT_DIR}/numforce/DlpolyJdir/FIELD .
  for jobidx in `seq 1 1 ${SMSS_PARJOBS_HISTORY}` ; do
    if [ -f HISTORY.${jobidx} ] ; then
      mkdir -p job-${jobidx}
      cp -n HISTORY.${jobidx} job-${jobidx}/HISTORY
      cp -f CONTROL FIELD MMS_ENSEMBLE job-${jobidx}/
    else
      echo "ERROR: smss-energy.sh (HISTORY.*)"
      exit 1
    fi
  done

  # Execute REPLAY jobs.
  for jobidx in `seq 1 1 ${SMSS_PARJOBS_HISTORY}` ; do
    cd job-${jobidx}
    SMSS_EXEC_DLPOLY=`echo "dlpoly-replay-history-4Cores"`
    ${SMSS_EXEC_DLPOLY} & 
    cd ..
  done
  wait

# Ensure that all REPLAY jobs finished successfully.
  for jobidx in `seq 1 1 ${SMSS_PARJOBS_HISTORY}` ; do
    SMSS_REPLAY_SUCCESS=`wc -l job-${jobidx}/MMS_REPLAY | grep 130000 | wc -l`
    while [ ${SMSS_REPLAY_SUCCESS} -ne 1 ] ; do
      cd job-${jobidx}
      rm -f MMS_REPLAY
      SMSS_EXEC_DLPOLY=`echo "dlpoly-replay-history-4Cores"`
      ${SMSS_EXEC_DLPOLY} &
      wait
      cd ..
      SMSS_REPLAY_SUCCESS=`wc -l job-${jobidx}/MMS_REPLAY | grep 130000 | wc -l`
    done
  done
  wait


  # Combine all REPLAY results.
  for jobidx in `seq 1 1 ${SMSS_PARJOBS_HISTORY}` ; do
    cat job-${jobidx}/MMS_REPLAY >> MMS_STEP
  done
fi

# Clean up temporary files.
cd ${SMSS_WDIR_BASE}
