#!/bin/sh

cd `dirname $0`

COMMON_CONFIG=genemodel_common.config
BIOTYPEMAPPING_CONFIG=biotypemapping.config

USAGE="Usage: biotypemapping.sh"

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
# Make sure the biotypemapping-specific configuration file exists and source it.
#
if [ -f ../${BIOTYPEMAPPING_CONFIG} ]
then
    . ../${BIOTYPEMAPPING_CONFIG}
else
    echo "Missing configuration file: ${BIOTYPEMAPPING_CONFIG}"
    exit 1
fi

#
# truncate the MRK_BioTypeMapping table
#
date
echo "Truncate the MRK_BioTypeMapping table"
${MGD_DBSCHEMADIR}/table/MRK_BiotypeMapping_truncate.object
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} truncate the MRK_BioTypeMapping table failed"
else
	message="${message} truncate the MRK_BioTypeMapping table successful" 
fi
echo ${message}

#
# load vocabulary terms
#
date
echo "Running biotype/vocload : ensembl.txt"
rm -rf ${INPUTDIR}/ensembl.txt
grep "^Ensembl" ${BIOTYPEINPUT_FILE_DEFAULT} > ${INPUTDIR}/ensembl.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensembl.config
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensembl.config failed"
else
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensembl.config successful" 
fi
echo ${message}

date
echo "Running biotype/vocload : ncbi.txt"
rm -rf ${BIOTYPEINPUTDIR}/ncbi.txt
grep "^NCBI" ${BIOTYPEINPUT_FILE_DEFAULT} > ${INPUTDIR}/ncbi.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ncbi.config
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ncbi.config failed"
else
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ncbi.config successful" 
fi
echo ${message}

date
echo "Running biotype/vocload : mgp.txt"
rm -rf ${INPUTDIR}/mgp.txt
grep "^MGP" ${BIOTYPEINPUT_FILE_DEFAULT} > ${INPUTDIR}/mgp.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_mgp.config
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_mgp.config failed"
else
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_mgp.config successful" 
fi
echo ${message}

date
echo "Running biotype/vocload : ensemblreg.txt"
rm -rf ${INPUTDIR}/ensemblreg.txt
grep "^VISTA" ${BIOTYPEINPUT_FILE_DEFAULT} > ${INPUTDIR}/ensemblreg.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensemblreg.config
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensemblreg.config failed"
else
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_ensemblreg.config successful" 
fi
echo ${message}

date
echo "Running biotype/vocload : vistareg.txt"
rm -rf ${INPUTDIR}/vistareg.txt
grep "^VISTA" ${BIOTYPEINPUT_FILE_DEFAULT} > ${INPUTDIR}/vistareg.txt
${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_vista.config
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_vista.config failed"
else
	message="${message} ${VOCLOAD}/runSimpleFullLoadNoArchive.sh biotype_vista.config successful" 
fi
echo ${message}

#
# Execute biotypemapping.py
#
date
echo "Running biotypemapping"
cd ${OUTPUTDIR}
${PYTHON} ${GENEMODELLOAD}/bin/biotypemapping.py
STAT=$?
if [ ${STAT} -ne 0 ]
then
	message="${message} ${GENEMODELLOAD}/bin/biotypemapping.py failed"
else
	message="${message} ${GENEMODELLOAD}/bin/biotypemapping.py successful"
fi
echo ${message}

#
# cat the biotype error file
#
cat ${BIOTYPELOG_ERROR}

exit 0
