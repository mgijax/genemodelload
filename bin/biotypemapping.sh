#!/bin/sh
#
#  biotypemapload.sh
###########################################################################
#
#  Purpose:
# 	This script runs the Nomenclature & Mapping load
#
  Usage=biotypemapload.sh
#
#  Env Vars:
#
#      See the configuration file biotypemapload.config
#
#  Inputs:
#
#      - configuration file - biotypemapload.config
#      - input file - see biotypemapload.config
#
#  Outputs:
#
#      - An archive file
#      - Log files defined by the environment variables ${LOG_PROC},
#        ${LOG_FILE}, ${LOG_FILE_CUR}, ${LOG_FILE_VAL}, ${LOG_ERROR}
#      - biotypemapload logs and bcp file to ${OUTPUTDIR}
#      - mappingload logs and bcp files  - see mappingload
#      - Records written to the database tables
#      - Exceptions written to standard error
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#
#  Assumes:  Nothing
#
#      This script will perform following steps:
#
#      1) Validate the arguments to the script.
#      2) Source the configuration file to establish the environment.
#      3) Verify that the input files exist.
#      4) Initialize the log file.
#      5) Determine if the input file has changed since the last time that
#         the load was run. Do not continue if the input file is not new.
#      6) Load biotypemapload using configuration file
#      7) Archive the input file.
#      8) Touch the "lastrun" file to timestamp the last run of the load.
#
# History:
#
# lec	10/21/2015
#	- TR12027/12116/biotype-mapping
#

cd `dirname $0`
LOG=`pwd`/biotypemapload.log
rm -rf ${LOG}

#
# Verify and source the configuration file
#
CONFIG_FILE=$1
if [ ! -r ${CONFIG_FILE} ]
then
   echo "Cannot read configuration file: ${CONFIG_FILE}" | tee -a ${LOG}
    exit 1   
fi

. ${CONFIG_FILE}

rm -rf ${LOG_FILE} ${LOG_PROC} ${LOG_DIAG} ${LOG_CUR} ${LOG_VAL} ${LOG_ERROR}

#
# use user-provied value or use config/default value
# Make sure the input file exists (regular file or symbolic link).
#
if [ $# -eq 2 ] 
then
    INPUT_FILE_DEFAULT=$2
fi
if [ ! -r ${INPUT_FILE_DEFAULT} ]
then
    echo "Missing input file: ${INPUT_FILE_DEFAULT}" | tee -a ${LOG_FILE}
    exit 1
fi

#
#  Source the DLA library functions.
#

if [ "${DLAJOBSTREAMFUNC}" != "" ]
then
    if [ -r ${DLAJOBSTREAMFUNC} ]
    then
        . ${DLAJOBSTREAMFUNC}
    else
        echo "Cannot source DLA functions script: ${DLAJOBSTREAMFUNC}" | tee -a ${LOG_FILE}
        exit 1
    fi  
else
    echo "Environment variable DLAJOBSTREAMFUNC has not been defined." | tee -a ${LOG_FILE}
    exit 1
fi

#####################################
#
# Main
#
#####################################

#
# dlautils/preload minus jobstream & archive
#
if [ ${BIOTYPEMAPMODE} != "preview" ]
then
    startLog ${LOG_PROC} ${LOG_DIAG} ${LOG_CUR} ${LOG_VAL} | tee -a ${LOG}
    getConfigEnv >> ${LOG_PROC}
    getConfigEnv -e >> ${LOG_DIAG}
fi

#
# There should be a "lastrun" file in the input directory that was created
# the last time the load was run for this input file. If this file exists
# and is more recent than the input file, the load does not need to be run.
#
if [ ${BIOTYPEMAPMODE} != "preview" ]
then
    LASTRUN_FILE=${INPUTDIR}/lastrun

    if [ -f ${LASTRUN_FILE} ]
    then
        if test ${LASTRUN_FILE} -nt ${INPUT_FILE_DEFAULT}
        then
            echo "SKIPPED: ${BIOTYPEMAPMODE} : Input file has not been updated" | tee -a ${LOG_FILE_PROC}
	    exit 0
        fi
    fi
fi

#
# truncate the MRK_BiotypeMapping table
# this is always a drop/reload
#
echo "" | tee -a ${LOG_FILE}
date | tee -a ${LOG_FILE}
echo "Truncating the MRK_BiotypeMapping table..." | tee -a ${LOG_FILE}
${PG_MGD_DBSCHEMADIR}/table/MRK_BiotypeMapping_truncate.object | tee -a ${LOG_FILE}
STAT=$?
checkStatus ${STAT} "${PG_MGD_DBSCHEMADIR}/table/MRK_BiotypeMapping_truncate.object:"

#
# load vocabulary terms
#
echo "" | tee -a ${LOG_FILE}
date | tee -a ${LOG_FILE}
echo "Running biotype/vocload : ensembl.txt" | tee -a ${LOG_FILE}
rm -rf ${INPUTDIR}/ensembl.txt
grep "^Ensembl" ${INPUT_FILE_DEFAULT} > ${INPUTDIR}/ensembl.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensembl.config | tee -a ${LOG_FILE}
STAT=$?
checkStatus ${STAT} "${VOCLOAD} biotype_ensembl.config:"

echo "Running biotype/vocload : ncbi.txt" | tee -a ${LOG_FILE}
rm -rf ${INPUTDIR}/ncbi.txt
grep "^NCBI" ${INPUT_FILE_DEFAULT} > ${INPUTDIR}/ncbi.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ncbi.config | tee -a ${LOG_FILE}
STAT=$?
checkStatus ${STAT} "${VOCLOAD} biotype_ncbi.config:"

echo "Running biotype/vocload : vega.txt" | tee -a ${LOG_FILE}
rm -rf ${INPUTDIR}/vega.txt
grep "^VEGA" ${INPUT_FILE_DEFAULT} > ${INPUTDIR}/vega.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_vega.config | tee -a ${LOG_FILE}
STAT=$?
checkStatus ${STAT} "${VOCLOAD} biotype_vega.config:"

#
# Execute biotypemapload
#
echo "" | tee -a ${LOG_FILE}
date | tee -a ${LOG_FILE}
echo "Running biotypemapload : ${BIOTYPEMAPMODE}" | tee -a ${LOG_FILE}
cd ${OUTPUTDIR}
${BIOTYPEMAPLOAD}/bin/biotypemapload.py | tee -a ${LOG_DIAG}
STAT=$?
checkStatus ${STAT} "${BIOTYPEMAPLOAD} ${CONFIG_FILE} : ${BIOTYPEMAPMODE} :"

#
# set permissions
#
case `whoami` in
    mgiadmin)
	chmod -f 775 ${FILEDIR}/*
	chgrp -f mgi ${FILEDIR}/*
	chgrp -f mgi ${FILEDIR}/*/*
	chmod -f 775 ${DESTFILEDIR}/*
	chgrp -f mgi ${DESTFILEDIR}/*
	chgrp -f mgi ${DESTFILEDIR}/*/*
	chgrp -f mgi ${BIOTYPEMAPLOAD}/bin
	chgrp -f mgi ${BIOTYPEMAPLOAD}/bin/biotypemapload.log
	;;
esac

#
# Archive : publshed only
# dlautils/preload with archive
#
if [ ${BIOTYPEMAPMODE} != "preview" ]
then
    createArchive ${ARCHIVEDIR} ${LOGDIR} ${INPUTDIR} ${OUTPUTDIR} | tee -a ${LOG}
fi 

#
# Touch the "lastrun" file to note when the load was run.
#
if [ ${BIOTYPEMAPMODE} != "preview" ]
then
    touch ${LASTRUN_FILE}
fi

#
# cat the error file
#
cat ${LOG_ERROR}

echo "" | tee -a ${LOG_FILE}
date | tee -a ${LOG_FILE}

#
# run postload cleanup and email logs
#
if [ ${BIOTYPEMAPMODE} != "preview" ]
then
    JOBKEY=0;export JOBKEY
    shutDown
fi

