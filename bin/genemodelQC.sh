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
#      genemodelQC.sh  provider_name  assoc_file [ -gm gm_file ] [ "live" ]
#
#      where
#          provider_name = ensembl, ncbi or vega
#          assoc_file = path to the association file
#          gm_file = path to the gene model file (optional)
#          live = option to let the script know that this is a "live" run
#                 so the output files are created under the /data/loads
#                 directory instead of the current directory
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
#      - Gene model input file with the following tab-delimited fields:
#
#          1) Gene Model ID
#          2) Chromosome
#          3) Start Coordinate
#          4) End Coordinate
#          5) Strand (+ or -)
#          6) Description
#
#      - Association input file with the following tab-delimited fields:
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
#      3) Determine which gene model file to use.
#      4) Verify that the input files exist.
#      5) Initialize the report files.
#      6) Clean up the input files by removing blank lines, Ctrl-M, etc.
#      7) Generate the sanity reports.
#      8) Create temp tables for the input data.
#      9) Load the input files into temp tables.
#      10) Call genemodelQC.py to generate the QC reports.
#      11) Drop the temp tables.
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

CURRENT_DIR=`pwd`

cd `dirname $0`

COMMON_CONFIG=genemodel_common.config

USAGE='Usage: genemodelQC.sh  provider_name  assoc_file [ -gm gm_file ] [ "live" ]'

GM_FILE_ARG=""
LIVE_RUN=0; export LIVE_RUN

#
# Make sure a valid provider name and association file were passed as
# arguments to the script. If the optional gene model file is given, it is
# used instead of the default gene model file. If the optional "live"
# argument is given, that means that the output files are located in the
# /data/loads/... directory, not in the current directory.
#
if [ $# -lt 2 -o $# -gt 5 ]
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

    ASSOC_FILE=$2

    while [ $# -gt 2 ]
    do
        if [ "$3" = "-gm" ]
        then
            GM_FILE_ARG=$4
            shift 2
        elif [ "$3" = "live" ]
        then
            LIVE_RUN=1
            shift 1
        else
            echo ${USAGE}; exit 1
        fi
    done
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
# If this is not a "live" run, the output files should reside in the
# current directory, so override the directory settings from the common
# configuration file before sourcing the provider-specific configuration
# file. This allows the file paths in the provider-specific configuration
# file to be established with the correct directory.
#
if [ ${LIVE_RUN} -eq 0 ]
then
    OUTPUTDIR=${CURRENT_DIR}
    LOGDIR=${CURRENT_DIR}
    RPTDIR=${CURRENT_DIR}
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
# Go to the directory where the script was invoked from, in case the
# input files are relative paths.
#
cd ${CURRENT_DIR}

#
# If the gene model file was provided as an argument to the script, use it.
# Otherwise, use the current gene model file (on hobbiton) if this is not
# a "live" run or use the default gene model file if this is a "live" run.
#
if [ "${GM_FILE_ARG}" != "" ]
then
    GM_FILE=${GM_FILE_ARG}
elif [ ${LIVE_RUN} -eq 0 ]
then
    GM_FILE=${GM_FILE_CURRENT}
else
    GM_FILE=${GM_FILE_DEFAULT}
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
if [ "`ls -L ${GM_FILE} 2>/dev/null`" = "" ]
then
    echo "Missing gene model input file: ${GM_FILE}" | tee -a ${LOG}
    exit 1
fi
if [ "`ls -L ${ASSOC_FILE} 2>/dev/null`" = "" ]
then
    echo "Missing association input file: ${ASSOC_FILE}" | tee -a ${LOG}
    exit 1
fi

#
# Initialize the report files to make sure the current user can write to them.
#
RPT_LIST="${GM_SANITY_RPT} ${ASSOC_SANITY_RPT} ${INVALID_MARKER_RPT} ${SEC_MARKER_RPT} ${MISSING_GMID_RPT} ${CHR_DISCREP_RPT} ${RPT_NAMES_RPT}"

for i in ${RPT_LIST}
do
    rm -f $i; >$i
done

#
# Create a temporary file and make sure it is removed when this script
# terminates.
#
TMP_FILE=/tmp/`basename $0`.$$
trap "rm -f ${TMP_FILE}" 0 1 2 15

#
# Make sure the association file has a header record that starts with
# "MGI ID" to indicate the the columns are in the proper order.
#
if [ "`head -1 ${ASSOC_FILE} | grep -i '^MGI ID'`" = "" ]
then
    echo "Invalid header record in association file" | tee -a ${LOG}
    exit 1
fi

#
# Convert the gene model file into a QC-ready version that can be used to
# run the sanity/QC reports against. This involves doing the following:
# 1) Extract columns 1 thru 6
# 2) Extract only lines that have alphanumerics (excludes blank lines)
# 3) Remove any Ctrl-M characters (dos2unix)
#
cat ${GM_FILE} | cut -d'	' -f1-6 | grep '[0-9A-Za-z]' > ${GM_FILE_QC}
dos2unix ${GM_FILE_QC} ${GM_FILE_QC} 2>/dev/null

#
# Convert the association file into a QC-ready version that can be used to
# run the sanity/QC reports against. This involves doing the following:
# 1) Remove the header record
# 2) Extract columns 1 & 2
# 3) Remove any spaces
# 4) Extract only lines that have alphanumerics (excludes blank lines)
# 5) Remove any Ctrl-M characters (dos2unix)
#
cat ${ASSOC_FILE} | tail -n +2 | cut -d'	' -f1,2 | sed 's/ //g' | grep '[0-9A-Za-z]' > ${ASSOC_FILE_QC}
dos2unix ${ASSOC_FILE_QC} ${ASSOC_FILE_QC} 2>/dev/null


#
# FUNCTION: Check for duplicate lines in an input file and write the lines
#           to the sanity report.
#
checkDupLines ()
{
    FILE=$1    # The input file to check
    REPORT=$2  # The sanity report to write to

    echo "Duplicate Lines" >> ${REPORT}
    echo "---------------" >> ${REPORT}
    sort ${FILE} | uniq -d > ${TMP_FILE}
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

    echo "" >> ${REPORT}
    echo "" >> ${REPORT}
    echo "Duplicate ${FIELD_NAME}" >> ${REPORT}
    echo "------------------------------" >> ${REPORT}
    cut -d'	' -f${FIELD_NUM} ${FILE} | sort | uniq -d > ${TMP_FILE}
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

    echo "" >> ${REPORT}
    echo "" >> ${REPORT}
    echo "Lines With Missing Columns" >> ${REPORT}
    echo "--------------------------" >> ${REPORT}
    cat ${FILE} | awk -F'	' '
        BEGIN {error=0}
        {
        if ( $0 == "" )
            break
        for ( i=1; i<=columns; i++ ) {
            if ( $i == "" ) {
                printf("%s\n", $0)
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
        echo "" >> ${REPORT}
        echo "" >> ${REPORT}
        echo "**** WARNING ****" >> ${REPORT}
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

checkDupLines ${GM_FILE_QC} ${GM_SANITY_RPT}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkDupFields ${GM_FILE_QC} ${GM_SANITY_RPT} 1 "Gene Model IDs"
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkColumns ${GM_FILE_QC} ${GM_SANITY_RPT} ${GM_FILE_COLUMNS}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

checkLineCount ${GM_FILE_QC} ${GM_SANITY_RPT} ${GM_FILE_MINIMUM_SIZE}
if [ $? -ne 0 ]
then
    GM_FILE_ERROR=1
fi

if [ ${GM_FILE_ERROR} -ne 0 ]
then
    echo "Sanity errors detected. See ${GM_SANITY_RPT}" | tee -a ${LOG}
fi

#
# Run sanity checks on the association input file.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Run sanity checks on the association input file" >> ${LOG}
ASSOC_FILE_ERROR=0

checkDupLines ${ASSOC_FILE_QC} ${ASSOC_SANITY_RPT}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

checkColumns ${ASSOC_FILE_QC} ${ASSOC_SANITY_RPT} ${ASSOC_FILE_COLUMNS}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

checkLineCount ${ASSOC_FILE_QC} ${ASSOC_SANITY_RPT} ${ASSOC_FILE_MINIMUM_SIZE}
if [ $? -ne 0 ]
then
    ASSOC_FILE_ERROR=1
fi

if [ ${ASSOC_FILE_ERROR} -ne 0 ]
then
    echo "Sanity errors detected. See ${ASSOC_SANITY_RPT}" | tee -a ${LOG}
fi

#
# If either input file had sanity errors, remove the QC-ready files and
# skip the QC reports.
#
if [ ${GM_FILE_ERROR} -ne 0 -o ${ASSOC_FILE_ERROR} -ne 0 ]
then
    rm -f ${GM_FILE_QC} ${ASSOC_FILE_QC}
    exit 1
fi

#
# Create temp tables for the input data.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Create temp tables for the input data" >> ${LOG}
cat - <<EOSQL | psql -h${PG_DBSERVER} -d${PG_DBNAME} -U mgd_dbo -e  >> ${LOG}

create table ${GM_TEMP_TABLE} (
    gmID varchar(80) not null,
    chromosome varchar(8) not null,
    startCoordinate float not null,
    endCoordinate float not null,
    strand char(1) not null,
    description varchar(255) not null
);

create  index idx_gmID on ${GM_TEMP_TABLE} (gmID);

create  index idx_chromosome on ${GM_TEMP_TABLE} (chromosome);

grant all on ${GM_TEMP_TABLE} to public;

create table ${ASSOC_TEMP_TABLE} (
    mgiID varchar(80) not null,
    gmID varchar(80) not null
);

create  index idx_mgiID on ${ASSOC_TEMP_TABLE} (mgiID);

create  index idx_gmID on ${ASSOC_TEMP_TABLE} (gmID);

grant all on ${ASSOC_TEMP_TABLE} to public;

EOSQL

#
# Generate the QC reports.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Generate the QC reports" >> ${LOG}
{ ${GENEMODEL_QC} ${ASSOC_FILE_QC} ${GM_FILE_QC} 2>&1; echo $? > ${TMP_FILE}; } >> ${LOG}
if [ `cat ${TMP_FILE}` -eq 1 ]
then
    echo "An error occurred while generating the QC reports"
    echo "See log file (${LOG})"
    RC=1
elif [ `cat ${TMP_FILE}` -eq 2 ]
then
    echo "QC errors detected in the following files: " | tee -a ${LOG}
    #echo `cat ${RPT_NAMES_RPT}` | tee -a ${LOG}
    cat ${RPT_NAMES_RPT}
    #cat ${RPT_NAMES_RPT} | while read a; do echo "$a" ; done | cat
else
    RC=0
fi

#
# Drop the temp tables.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Drop the temp tables" >> ${LOG}
cat - <<EOSQL | psql -h${PG_DBSERVER} -d${PG_DBNAME} -U mgd_dbo -e  >> ${LOG}

drop table ${GM_TEMP_TABLE};

drop table ${ASSOC_TEMP_TABLE};

EOSQL

date >> ${LOG}

#
# Remove the bcp files.
#
rm -f ${GM_FILE_BCP} ${ASSOC_FILE_BCP}

#
# Remove the QC-ready association file.
#
rm -f ${ASSOC_FILE_QC}

#
# If this is a "live" run, move the QC-ready gene model file to the
# load-ready gene model file. Otherwise, remove it.
#
if [ ${LIVE_RUN} -eq 1 ]
then
    mv ${GM_FILE_QC} ${GM_FILE_LOAD}
else
    rm -f ${GM_FILE_QC}
fi

exit ${RC}
