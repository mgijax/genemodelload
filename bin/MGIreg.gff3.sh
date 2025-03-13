#!/bin/sh
#
# MGIreg.gff3.sh
###########################################################################
#
#  Purpose:
#       This script is a wrapper for MGIreg.gff3.py
#  Usage:
#       MGIreg.gff3.sh
#
###########################################################################
#
#  Modification History:
#
#  03/06/2025  lec   wts2-1538/e4g-9/MGI Regulatory GFF changes: MGIreg.gff3
#
###########################################################################

cd `dirname $0`

COMMON_CONFIG=genemodel_common.config
GFF_CONFIG=mgireg.gff3.config

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

# unzip and copy to input dir the ensembl gff
echo "gunzip -c ${ENSEMBL_GFF} > ${ENSEMBL_GFF_DEFAULT}" | tee -a ${LOG}
gunzip -c ${ENSEMBL_GFF} > ${ENSEMBL_GFF_DEFAULT} | tee -a ${LOG}

# unzip and copy to input dir the ncbi gff
echo "gunzip -c ${NCBI_GFF} > ${NCBI_GFF_DEFAULT}" | tee -a ${LOG}
gunzip -c ${NCBI_GFF} > ${NCBI_GFF_DEFAULT} | tee -a ${LOG}

# copy to input dir the vista gff
echo "${VISTA_GFF} > ${VISTA_GFF_DEFAULT}" | tee -a ${LOG}
cp ${VISTA_GFF} ${VISTA_GFF_DEFAULT} | tee -a ${LOG}

echo `date`: $i | tee -a ${LOG}
${PYTHON} ${GENEMODELLOAD}/bin/MGIreg.gff3.py >> ${LOG} 2>&1

#
# Copy report to ftp site
#
cd ${OUTPUTDIR}
cat MGIreg.gff3 | gzip -cf9 > MGIreg.gff3.gz
touch MGIreg.gff3.gz
cp -p MGIreg.gff3.gz ${DISTRIBDIR}/

echo `date`: End MGIreg.gff3 public report | tee -a ${LOG}

exit 0
