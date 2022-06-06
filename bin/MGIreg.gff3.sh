#!/bin/sh
#
# MGIreg.gff3.sh
###########################################################################
#
#  Purpose:
#
#       This script is a wrapper around process that creates the MGI i
#       regulatory marker gff report
#  Usage:
#
#       MGIreg.gff3.sh
#  Env Vars:
#  Inputs:
#  Outputs:
#  Exit Codes:
###########################################################################
#
#  Modification History:
#
#  Date        SE   Change Description
#  ----------  ---  -------------------------------------------------------
#
#  05/18/2022  sc   Initial development
#
###########################################################################


cd `dirname $0`

COMMON_CONFIG=genemodel_common.config
GFF_CONFIG=mgireg.gff3.config
#
# verify & source the configuration file
#

if [ -f ../${COMMON_CONFIG} ]
then
    . ../${COMMON_CONFIG}
else
    echo "Missing configuration file: ${COMMON_CONFIG}"
    exit 1
fi

if [ -f ../${GFF_CONFIG} ]
then
    . ../${GFF_CONFIG}
else
    echo "Missing configuration file: ${GFF_CONFIG}"
    exit 1
fi

umask 002

#
# Initialize the log file.
#
LOG=${LOGDIR}/`basename $0`.log
rm -rf ${LOG}
touch ${LOG}

echo `date`: Start MGIreg.gff3 public report | tee -a ${LOG}

# unzip and copy to input dir the ensembl gff we get the bounds from
echo "gunzip -c ${ENSEMBL_GFF} > ${ENSEMBL_GFF_DEFAULT}" | tee -a ${LOG}
gunzip -c ${ENSEMBL_GFF} > ${ENSEMBL_GFF_DEFAULT}

echo `date`: $i | tee -a ${LOG}
${PYTHON} ${GENEMODELLOAD}/bin/MGIreg.gff3.py >> ${LOG} 2>&1

#
# Copy report to ftp site
#
cd ${OUTPUTDIR}

echo `date`: Copy report to ftp site | tee -a ${LOG}

cat MGIreg.gff3 | gzip -cf9 > MGIreg.gff3.gz
touch MGIreg.gff3.gz
cp -p MGIreg.gff3.gz ${DISTRIBDIR}/

echo `date`: End MGIreg.gff3 public report | tee -a ${LOG}

exit 0
