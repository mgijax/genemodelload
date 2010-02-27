#!/bin/sh 
#
#  seqgenemodelload.sh
###########################################################################
#
#  Purpose:
#
#      This script serves as a wrapper for seqgenemodelload.py
#
#  Usage:
#
#      seqgenemodelload.sh <ensembl | ncbi | vega>
#
#
#  Env Vars:
#
#      	INFILE_NAME_BIOTYPE
#	SEQGENEMODELLOAD_LOGFILE
#	BCP_FILE_PATH
#	PROVIDER_LOGICALDB
#
#  Inputs: ${INFILE_NAME_BIOTYPE}
#
#  Outputs:
#       - SEQ_GeneModel bcp file
#       - Log file (${SEQGENEMODELLOAD_LOGFILE})
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
#      1) Determine the provider based upon $1 config file and source it.
#      2) Call the python script (seqgenemodelload.py) to create a bcp file
#	  for SEQ_GeneModel
#      3) Delete SEQ_GeneModel data for provider
#      4) Load the bcp file into the SEQ_GeneModel  table
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
#  01/26/2010  sc   Initial development
#
###########################################################################

cd `dirname $0`

COMMON_CONFIG=genemodel_common.config

USAGE="Usage: test.sh <ensembl | ncbi | vega>"

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
LOG=${SEQGENEMODELLOAD_LOGFILE}
rm -rf ${LOG}
touch ${LOG}

date >> ${LOG}

#
# Make sure the input file exists
#
if [ ! -f ${INFILE_NAME_BIOTYPE} ]
then
    echo "Input file does not exist: ${INFILE_NAME_BIOTYPE}" | tee -a ${LOG}
    exit 1
fi

echo "Creating bcp file" | tee -a  ${LOG}
gunzip -c ${INFILE_NAME_BIOTYPE} | ./seqgenemodelload.py ${PROVIDER} >> ${LOG} 2>&1
STAT=$?
if [ STAT -ne 0 ]
then
   echo "seqgenemodelload failed" | tee -a ${LOG}
   QUIT=1
elif [ ! -s ${BCP_FILE_PATH} ]
then
    echo "The bcp file is empty" | tee -a ${LOG}
    QUIT=1
else
    QUIT=0
fi

#
# Do not attempt to delete/reload SEQ_GeneModel for the provider 
# if there was a problem creating the bcp file
#
if [ ${QUIT} -eq 1 ]
then
    exit 1
fi

#
# delete SEQ_GeneModel records for current provider
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Deleting the existing records for ${PROVIDER}" | tee -a ${LOG}
cat - <<EOSQL | isql -S${MGD_DBSERVER} -D${MGD_DBNAME} -Umgd_dbo -P`cat ${MGD_DBPASSWORDFILE}` -e >> ${LOG}

declare @logicalDBKey int
select @logicalDBKey = _LogicalDB_key
from ACC_LogicalDB
where name = '${PROVIDER_LOGICALDB}'

select _Object_key as _Sequence_key
into #tmp_gmKey
from ACC_Accession
where _MGIType_key = 19
and preferred = 1
and _LogicalDB_key = @logicalDBKey
go

delete SEQ_GeneModel
from SEQ_GeneModel s, #tmp_gmKey t
where s._Sequence_key = t._Sequence_key
go

quit
EOSQL

#
# Load SEQ_GeneModel for current provider
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Adding records for  ${PROVIDER}" | tee -a ${LOG}

cat ${MGD_DBPASSWORDFILE} | bcp ${MGD_DBNAME}..SEQ_GeneModel in ${BCP_FILE_PATH} -c -t\\t -S${MGD_DBSERVER} -U${MGD_DBUSER} >> ${LOG}

date >> ${LOG}

exit 0