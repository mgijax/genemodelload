#!/bin/sh
#
#  genemodelload.sh
###########################################################################
#
#  Purpose:
#
#      This script is a wrapper around the process that loads the gene
#      models and/or the associations for a given provider.
#
#  Usage:
#
#      genemodelload.sh  provider_name
#
#      where
#          provider_name = ensembl, ncbi or vega
#
#  Env Vars:
#
#      See the configuration files
#
#      - Common configuration file (genemodel_common.config)
#
#      - Provider-specific configuration file (one of these):
#          - genemodel_ensembl.config
#          - genemodel_ncbi.config
#          - genemodel_vega.config
#
#  Inputs:
#
#      - Gene model input file (${GM_FILE_DEFAULT}) with the following
#        tab-delimited fields:
#
#          1) Gene Model ID
#          2) Chromosome
#          3) Start Coordinate
#          4) End Coordinate
#          5) Strand (+ or -)
#          6) Description
#
#      - Association input file (${ASSOC_FILE_DEFAULT}) with the following
#        tab-delimited fields:
#
#          1) MGI ID for the Marker
#          2) Gene Model ID
#
#  Outputs:
#
#      - Log file (${GENEMODELLOAD_LOGFILE})
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  Fatal error occurred
#
#  Assumes:  Nothing
#
#  Implementation:
#
#      This script will perform following steps:
#
#      1) Validate the arguments to the script.
#      2) Source the configuration files to establish the environment.
#      3) Verify that the input files exist.
#      4) Call genemodelQC.sh to generate the sanity/QC reports.
#      5) Verify that the association file has been updated since the
#         last time that the load ran.
#      6) Load the gene models (optional) and the associations.
#      7) Archive the input files.
#      8) Touch the "lastrun" file to timestamp the last run of the load.
#
#  Notes:  None
#
###########################################################################
#
#  Modification History:
#
#  Date        SE   Change Description
#  ----------  ---  -------------------------------------------------------
#
#  09/30/2008  DBM  Initial development
#
###########################################################################

cd `dirname $0`

COMMON_CONFIG=genemodel_common.config

USAGE="Usage: genemodelload.sh {ensembl | ncbi | vega}"

RUNTYPE=live

#
# Make sure a valid provider name was passed as an argument and determine
# which configuration file to use.
#
if [ $# -lt 1 ]
then
    echo ${USAGE}; exit 1
elif [ "`echo $1 | grep -i '^ensembl$'`" != "" ]
then
    PROVIDER=ensembl
    CONFIG=genemodel_ensembl.config
elif [ "`echo $1 | grep -i '^ncbi$'`" != "" ]
then
    PROVIDER=ncbi
    CONFIG=genemodel_ncbi.config
elif [ "`echo $1 | grep -i '^vega$'`" != "" ]
then
    PROVIDER=vega
    CONFIG=genemodel_vega.config
else
    echo ${USAGE}; exit 1
fi

#
# Make sure the common configuration file exists and source it.
#
if [ -f ../${COMMON_CONFIG} ]
then
    . ../${COMMON_CONFIG}
else
    echo "Missing configuration file: ${COMMON_CONFIG}"
    exit 1
fi

#
# Make sure the provider-specific configuration file exists and source it.
#
if [ -f ../${CONFIG} ]
then
    . ../${CONFIG}
else
    echo "Missing configuration file: ${CONFIG}"
    exit 1
fi

#
# Initialize the log file.
#
LOG=${GENEMODELLOAD_LOGFILE}
rm -rf ${LOG}
touch ${LOG}

#
# Make sure the input files exist (regular file or symbolic link).
#
if [ "`ls -L ${GM_FILE_DEFAULT} 2>/dev/null`" = "" ]
then
    echo "Missing gene model input file: ${GM_FILE_DEFAULT}" | tee -a ${LOG}
    exit 1
fi
if [ "`ls -L ${ASSOC_FILE_DEFAULT} 2>/dev/null`" = "" ]
then
    echo "Missing association input file: ${ASSOC_FILE_DEFAULT}" | tee -a ${LOG}
    exit 1
fi

#
# Create a temporary file and make sure the it is removed when this script
# terminates.
#
TMP_FILE=/tmp/`basename $0`.$$
trap "rm -f ${TMP_FILE}" 0 1 2 15

#
# Generate the sanity/QC reports.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Generate the sanity/QC reports" | tee -a ${LOG}
{ ${GENEMODEL_QC_SH} ${PROVIDER} ${ASSOC_FILE_DEFAULT} ${RUNTYPE} 2>&1; echo $? > ${TMP_FILE}; } >> ${LOG}
if [ `cat ${TMP_FILE}` -eq 1 ]
then
    echo "QC reports failed" | tee -a ${LOG}
    exit 1
fi

#
# There should be a "lastrun" file in the input directory that was created
# the last time the gene model load was run for the given provider. If this
# file exists and is more recent than the association file, the load does
# not need to be run.
#
LASTRUN_FILE=${INPUTDIR}/${GM_PROVIDER}.lastrun
if [ -f ${LASTRUN_FILE} ]
then
    if /usr/local/bin/test ${LASTRUN_FILE} -nt ${ASSOC_FILE_DEFAULT}
    then
        echo "Association file has not been updated - skipping load" | tee -a ${LOG}
        exit 0
    fi
fi

#
# If the gene models are to be reloaded in addition to the associations, call
# the assemblyseqload. Otherwise, call the wrapper for the association load.
#
echo "" >> ${LOG}
date >> ${LOG}
if [ ${RELOAD_GENEMODELS} = "true" ]
then
    echo "Load gene models and associations" | tee -a ${LOG}
#    ${ASSEMBLY_WRAPPER} ${ASSEMBLY_CONFIG} >> ${LOG}
else
    echo "Load gene model associations" | tee -a ${LOG}
#    ${ASSOCLOAD_WRAPPER} ${ASSEMBLY_CONFIG} >> ${LOG}
fi

TIMESTAMP=`date '+%Y%m%d.%H%M'`

#
# Archive a copy of each of the input files, adding a timestamp suffix.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Archive input files" | tee -a ${LOG}
for FILE in ${GM_FILE_DEFAULT} ${ASSOC_FILE_DEFAULT}
do
    ARC_FILE=`basename ${FILE}`.${TIMESTAMP}
    cp -p $FILE ${ARCHIVEDIR}/${ARC_FILE}
done

#
# Touch the "lastrun" file to note when the load was run.
#
touch ${LASTRUN_FILE}

exit 0
