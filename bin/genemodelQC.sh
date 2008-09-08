#!/bin/sh
#
#  genemodelQC.sh
###########################################################################
#
#  Purpose:
#
#      This script is a wrapper around the process that creates sanity/QC
#      reports for a pair of gene model/association files.
#
#  Usage:
#
#      genemodelQC.sh  provider_name  [ "live" ]
#
#      where
#          provider_name = ensembl, ncbi or vega
#          live = option to let the script know that this is a "live" run
#                 so the input/output files should be under the /data/loads
#                 directory instead of the current directory
#
#      NOTE:
#          When someone invokes this script to test a pair of input files,
#          they should invoke it from the directory where the input files
#          exist and the "live" option should NOT be used. This tells the
#          script to look in the current directory for the input files and
#          to create the reports and other output files in the current
#          directory too.
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
#      - Gene model input file (${GM_FILE}) with the following tab-delimited
#        fields:
#
#          1) Gene Model ID
#          2) Chromosome
#          3) Start Coordinate
#          4) End Coordinate
#          5) Strand (+ or -)
#          6) Description
#
#      - Association input file (${ASSOC_FILE}) with the following
#        tab-delimited fields:
#
#          1) MGI ID for the Marker
#          2) Gene Model ID
#
#  Outputs:
#
#      - Sanity report for the gene model input file.
#
#      - Sanity report for the association input file.
#
#      - Log file (${GENEMODELQC_LOGFILE})
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
#      4) Initialize the report files.
#      5) Generate the sanity reports.
#      6) Create temp tables for the input data.
#      7) Load the input files into temp tables.
#      8) Call genemodelQC.py to generate the QC reports.
#      9) Drop the temp tables.
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
#  09/08/2008  DBM  Initial development
#
###########################################################################

CURRENT_DIR=`pwd`

cd `dirname $0`

COMMON_CONFIG=genemodel_common.config

USAGE="Usage: genemodelQC.sh {ensembl | ncbi | vega}"

LIVE_RUN=0; export LIVE_RUN

#
# Make sure a valid provider name was passed as the first argument to
# determine which configuration file to use.  If the second optional
# argument is "live", that means that the data files are located in the
# /data/loads/... directory, not in the current directory.
#
if [ $# -lt 1 -o $# -gt 2 ]
then
    echo ${USAGE}; exit 1
else
    if [ "`echo $1 | grep -i '^ensembl$'`" != "" ]
    then
        CONFIG=genemodel_ensembl.config
    elif [ "`echo $1 | grep -i '^ncbi$'`" != "" ]
    then
        CONFIG=genemodel_ncbi.config
    elif [ "`echo $1 | grep -i '^vega$'`" != "" ]
    then
        CONFIG=genemodel_vega.config
    else
        echo ${USAGE}; exit 1
    fi

    if [ $# -eq 2 ]
    then
        if [ "$2" = "live" ]
        then
            LIVE_RUN=1
        else
            echo ${USAGE}; exit 1
        fi
    fi
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
# If this is not a "live" run, the input/output files should reside in the
# current directory, so override the directory settings from the common
# configuration file before sourcing the provider-specific configuration
# file. This allows the file paths in the provider-specific configuration
# file to be established with the correct directory.
#
if [ ${LIVE_RUN} -eq 0 ]
then
    INPUTDIR=${CURRENT_DIR}
    LOGDIR=${CURRENT_DIR}
    RPTDIR=${CURRENT_DIR}
    OUTPUTDIR=${CURRENT_DIR}
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
LOG=${GENEMODELQC_LOGFILE}
rm -rf ${LOG}
touch ${LOG}

#
# Make sure the input files exist (regular file or symbolic link).
#
if [ ! -f ${GM_FILE} -a ! -h ${GM_FILE} ]
then
    echo "Missing gene model input file: ${GM_FILE}" | tee -a ${LOG}
    exit 1
fi
if [ ! -f ${ASSOC_FILE} -a ! -h ${ASSOC_FILE} ]
then
    echo "Missing association input file: ${ASSOC_FILE}" | tee -a ${LOG}
    exit 1
fi

#
# Initialize the report files to make sure the current user can write to them.
#
RPT_LIST="${GM_SANITY_RPT} ${ASSOC_SANITY_RPT} ${INVALID_MARKER_RPT} ${SEC_MARKER_RPT} ${MISSING_GMID_RPT} ${CHR_DISCREP_RPT}"

for i in ${RPT_LIST}
do
    rm -f $i; >$i
done

#
# Create a temporary file and make sure the it is removed when this script
# terminates.
#
TMP_FILE=/tmp/`basename $0`.$$
trap "rm -f ${TMP_FILE}" 0 1 2 15


#
# FUNCTION: Check for blank lines in an input file and write the line numbers
#           to the sanity report.
#
checkBlankLines ()
{
    FILE=$1    # The input file to check
    REPORT=$2  # The sanity report to write to

    echo "Blank Line Numbers" >> ${REPORT}
    echo "------------------" >> ${REPORT}
    RC=0
    for i in `sed 's/ 	//g' ${FILE} | grep -n '^$' | cut -d':' -f1`
    do
        echo "Line $i" >> ${REPORT}
        RC=1
    done
    return ${RC}
}


#
# FUNCTION: Check for duplicate lines in an input file and write the lines
#           to the sanity report.
#
checkDupLines ()
{
    FILE=$1    # The input file to check
    REPORT=$2  # The sanity report to write to

    echo "\n\nDuplicate Lines" >> ${REPORT}
    echo "---------------" >> ${REPORT}
    grep -v '^$' ${FILE} | sort | uniq -d > ${TMP_FILE}
    cat ${TMP_FILE} >> ${REPORT}
    if [ `cat ${TMP_FILE} | wc -l` -eq 0 ]
    then
        return 0
    else
        return 1
    fi
}


#
# FUNCTION: Check for a duplicated field in an input file and write the field
#           value to the sanity report.
#
checkDupFields ()
{
    FILE=$1         # The input file to check
    REPORT=$2       # The sanity report to write to
    FIELD_NUM=$3    # The field number to check
    FIELD_NAME=$4   # The field name to show on the sanity report

    echo "\n\nDuplicate ${FIELD_NAME}" >> ${REPORT}
    echo "------------------------------" >> ${REPORT}
    grep -v '^$' ${FILE} | cut -d'	' -f${FIELD_NUM} | sort | uniq -d > ${TMP_FILE}
    cat ${TMP_FILE} >> ${REPORT}
    if [ `cat ${TMP_FILE} | wc -l` -eq 0 ]
    then
        return 0
    else
        return 1
    fi
}


#
# FUNCTION: Check for lines with missing columns in an input file and write
#           the line numbers to the sanity report.
#
checkColumns ()
{
    FILE=$1         # The input file to check
    REPORT=$2       # The sanity report to write to
    NUM_COLUMNS=$3  # The number of columns expected in each input record

    echo "\n\nLines With Missing Columns" >> ${REPORT}
    echo "--------------------------" >> ${REPORT}
    cat ${FILE} | awk -F'	' '
        BEGIN {error=0}
        {
        if ( $0 == "" )
            break
        for ( i=1; i<=columns; i++ ) {
            if ( $i == "" ) {
                printf("Line %d: %s\n", NR, $0)
                error=1
                break
                }
            }
        }
        END {exit error}' columns=${NUM_COLUMNS} >> ${REPORT}
    return $?
}


#
# FUNCTION: Check an input file to make sure it has a minimum number of lines.
#
checkLineCount ()
{
    FILE=$1        # The input file to check
    REPORT=$2      # The sanity report to write to
    NUM_LINES=$3   # The minimum number of lines expected in the input file

    COUNT=`cat ${FILE} | wc -l | sed 's/ //g'`
    if [ ${COUNT} -lt ${NUM_LINES} ]
    then
        echo "\n\n**** WARNING ****" >> ${REPORT}
        echo "${FILE} has ${COUNT} lines." >> ${REPORT}
        echo "Expecting at least ${NUM_LINES} lines." >> ${REPORT}
        return 1
    else
        return 0
    fi
}


#
# Run sanity checks on the gene model input file.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Run sanity checks on the gene model input file" >> ${LOG}
GM_FILE_ERROR=0

checkBlankLines ${GM_FILE} ${GM_SANITY_RPT}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkDupLines ${GM_FILE} ${GM_SANITY_RPT}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkColumns ${GM_FILE} ${GM_SANITY_RPT} ${GM_FILE_COLUMNS}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkLineCount ${GM_FILE} ${GM_SANITY_RPT} ${GM_FILE_MINIMUM_SIZE}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkDupFields ${GM_FILE} ${GM_SANITY_RPT} 1 "Gene Model IDs"
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

if [ ${GM_FILE_ERROR} -ne 0 ]
then
    echo "Sanity errors detected in gene model file" | tee -a ${LOG}
fi

#
# Run sanity checks on the association input file.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Run sanity checks on the association input file" >> ${LOG}
ASSOC_FILE_ERROR=0

checkBlankLines ${ASSOC_FILE} ${ASSOC_SANITY_RPT}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

checkDupLines ${ASSOC_FILE} ${ASSOC_SANITY_RPT}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

checkColumns ${ASSOC_FILE} ${ASSOC_SANITY_RPT} ${ASSOC_FILE_COLUMNS}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

checkLineCount ${ASSOC_FILE} ${ASSOC_SANITY_RPT} ${ASSOC_FILE_MINIMUM_SIZE}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

if [ ${ASSOC_FILE_ERROR} -ne 0 ]
then
    echo "Sanity errors detected in association file" | tee -a ${LOG}
fi

#
# If either input file had sanity errors, skip the QC reports.
#
if [ ${GM_FILE_ERROR} -ne 0 -o ${ASSOC_FILE_ERROR} -ne 0 ]
then
    exit 1
fi

#
# Create temp tables for the input data.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Create temp tables for the input data" >> ${LOG}
cat - <<EOSQL | isql -S${MGD_DBSERVER} -D${MGD_DBNAME} -U${MGI_PUBLICUSER} -P`cat ${MGI_PUBPASSWORDFILE}` -e  >> ${LOG}

use tempdb
go

create table ${TEMP_GM_TABLE} (
    gmID varchar(80) not null,
    chromosome varchar(8) not null,
    startCoordinate float not null,
    endCoordinate float not null,
    strand char(1) not null,
    description varchar(255) not null
)
go

create nonclustered index idx_gmID on ${TEMP_GM_TABLE} (gmID)
go

create nonclustered index idx_chromosome on ${TEMP_GM_TABLE} (chromosome)
go

grant all on ${TEMP_GM_TABLE} to public
go

create table ${TEMP_ASSOC_TABLE} (
    mgiID varchar(80) not null,
    gmID varchar(80) not null
)
go

create nonclustered index idx_mgiID on ${TEMP_ASSOC_TABLE} (mgiID)
go

create nonclustered index idx_gmID on ${TEMP_ASSOC_TABLE} (gmID)
go

grant all on ${TEMP_ASSOC_TABLE} to public
go

quit
EOSQL

#
# Generate the QC reports.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Generate the QC reports" >> ${LOG}
{ ${GENEMODEL_QC} 2>&1; echo $? > ${TMP_FILE}; } >> ${LOG}
if [ `cat ${TMP_FILE}` -eq 1 ]
then
    echo "An error occurred while generating the QC reports"
    echo "See log file (${LOG})"
    RC=1
elif [ `cat ${TMP_FILE}` -eq 2 ]
then
    echo "QC errors detected" | tee -a ${LOG}
    RC=0
else
    RC=0
fi

#
# Drop the temp tables.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Drop the temp tables" >> ${LOG}
cat - <<EOSQL | isql -S${MGD_DBSERVER} -D${MGD_DBNAME} -U${MGI_PUBLICUSER} -P`cat ${MGI_PUBPASSWORDFILE}` -e  >> ${LOG}

use tempdb
go

drop table ${TEMP_GM_TABLE}
go

drop table ${TEMP_ASSOC_TABLE}
go

quit
EOSQL

date >> ${LOG}

#
# If this is not a "live" run, remove the files that are not needed from
# the current directory.
#
if [ ${LIVE_RUN} -eq 0 ]
then
    rm -f ${TEMP_GM_BCPFILE} ${TEMP_ASSOC_BCPFILE}
fi

exit ${RC}
