#!/bin/sh
#
#  genemodelload.sh
###########################################################################
#
#  Purpose:
#
#      This script is a wrapper around the process that loads the gene
#      models and/or marker associations for a given provider.
#      As of MGI4.33 (TR9782) This script also runs the loading of
#      1) SEQ_GeneModel (A script in this product) 
#      2) Ensembl transcript/protein sequence loads and marker 
#         associations, Ensembl transcript/protein sequence
#         associations  (ensemblseqload)
#
#  Usage:
#
#      genemodelload.sh  provider_name
#
#      where
#          provider_name = ensembl, ncbi
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
BIOTYPEMAPPING_CONFIG=biotypemapping.config

USAGE="Usage: genemodelload.sh {ensembl | ncbi | ensemblreg}"

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
elif [ "`echo $1 | grep -i '^ensemblreg$'`" != "" ]
then
    PROVIDER=ensemblreg
    CONFIG=genemodel_ensemblreg.config
elif [ "`echo $1 | grep -i '^vistareg$'`" != "" ]
then
    PROVIDER=vistareg
    CONFIG=genemodel_vistareg.config
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
# There should be a "lastrun" file in the input directory that was created
# the last time the gene model load was run for the given provider. If this
# file exists and is more recent than the association file, the load does
# not need to be run.
#
LASTRUN_FILE=${INPUTDIR}/${GM_PROVIDER}.lastrun
if [ -f ${LASTRUN_FILE} ]
then
    if test ${LASTRUN_FILE} -nt ${ASSOC_FILE_DEFAULT}
    then
        echo "Association file has not been updated - skipping load" | tee -a ${LOG}
        exit 0
    fi
fi

#
# If the gene models are to be reloaded, the following is done for *all* PROVIDERs:
#	- remove version numbers from gz files
#	- reload the PROVIDER/biotype vocabulary
#	- reload the MRK_BiotypeMapping table
#
if [ ${RELOAD_GENEMODELS} = "true" ]
then

#
# TR12116
# for Ensembl provider, remove the version number from the accession ids (if they exist)
# gunzip the file ; remove the version number ; gzip the file again
#
if [ ${PROVIDER} = "ensembl" ]
then
echo "" >> ${LOG}
date >> ${LOG}
echo "Removing version numbers from gz files..." | tee -a ${LOG}
cd ${INPUTDIR}
for file1 in ${TRANSCRIPT_FILE_DEFAULT} ${PROTEIN_FILE_DEFAULT} ${NCRNA_FILE_DEFAULT}
do
file2=`basename ${file1} .gz`
gunzip ${file1}
sed 's/\.[0-9]*//g' ${file2} | gzip -c > ${file1}
rm -rf ${file2}
done
cd `dirname $0`
fi

echo "" >> ${LOG}
date >> ${LOG}
echo "Running BioType-Mapping" | tee -a ${LOG}
${GENEMODELLOAD}/bin/biotypemapping.sh | tee -a ${LOG}
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo "${PROVIDER} ${GENEMODELLOAD}/bin/biotypemapping.sh failed" | tee -a ${LOG}
else
	echo "${PROVIDER} ${GENEMODELLOAD}/bin/biotypemapping.sh successful" | tee -a ${LOG}
fi

fi

### end if [ ${RELOAD_GENEMODELS} = "true" ]

#
# Run sanity/QC reports
#
# a distinct tmp file is created  to allow > 1 curator to run a QC check
# make sure the tmp file is removed when this script terminates
#
date >> ${LOG}
echo "Generate the sanity/QC reports" | tee -a ${LOG}
TMP_FILE=/tmp/`basename $0`.$$
trap "rm -f ${TMP_FILE}" 0 1 2 15
{ ${GENEMODEL_QC_SH} ${PROVIDER} ${ASSOC_FILE_DEFAULT} ${RUNTYPE} 2>&1; echo $? > ${TMP_FILE}; } >> ${LOG}
if [ `cat ${TMP_FILE}` -eq 1 ]
then
    echo "QC reports failed" | tee -a ${LOG}
    exit 1
fi

#
# If the gene models are to be reloaded, the following is done for PROVIDER:
# 1) call the assemblyseqload to reload genemodels, coordinates and
#    marker associations
# 2) call the seqgenemodelload to reload SEQ_GeneModel
# 3) if Ensembl, call the ensemblseqload to reload 
#    a) transcript and protein sequences 
#    b) marker associations to transcript and protein sequences
#    d) relationships between transcript and protein sequences
#
echo "" >> ${LOG}
date >> ${LOG}
if [ ${RELOAD_GENEMODELS} = "true" ]
then
    echo "Load gene models and associations for ${PROVIDER}" | tee -a ${LOG}
    ${ASSEMBLY_WRAPPER} ${ASSEMBLY_CONFIG} >> ${LOG}

    echo "Load SEQ_GeneModel for ${PROVIDER}" | tee -a ${LOG}
    ${GENEMODELLOAD}/bin/seqgenemodelload.sh ${PROVIDER} >> ${LOG} 2>&1
    STAT=$?
    if [ ${STAT} -ne 0 ]
    then
        echo "${PROVIDER} seqgenemodelload.sh failed" | tee -a ${LOG}
	exit 1
    else
        echo "${PROVIDER} seqgenemodelload.sh successful" | tee -a ${LOG}
    fi

    if [ ${PROVIDER} = "ensembl" ]
    then
	echo "Load protein/transcript sequences and marker associations for ${PROVIDER}" | tee -a ${LOG}
        # order is important, transcripts must be loaded first so 
	# proteins can be associated with them
        ${ENS_WRAPPER} ensembl_transcriptseqload.config true >> ${LOG} 2>&1
	${ENS_WRAPPER} ensembl_proteinseqload.config true >> ${LOG} 2>&1
    fi
#
# If only the gene model associations are to be reloaded:
# 1) reload gene model marker associations
# 2) if Ensembl, call the ensemblseqload to reload 
#    marker associations to transcript and protein sequences
#
else
    echo "Load gene model associations for ${PROVIDER}" | tee -a ${LOG}
    ${ASSOCLOAD_WRAPPER} ${ASSEMBLY_CONFIG} >> ${LOG} 2>&1

    if [ ${PROVIDER} = "ensembl" ]
    then
	echo "Load protein/transcript marker associations for ${PROVIDER}" | tee -a ${LOG}
        ${ENS_WRAPPER} ensembl_transcriptseqload.config false >> ${LOG} 2>&1
        ${ENS_WRAPPER} ensembl_proteinseqload.config false >> ${LOG} 2>&1
    fi
fi

# regenerate the MGIreg.gff3 file
# only use during testing
# these are called from the loadadmin/prod/sunday tasks
#echo "Creating MGIreg.gff3 file" | tee -a ${LOG}
#${GENEMODELLOAD}/bin/runGeneModelCache.sh | tee -a ${LOG}
#${GENEMODELLOAD}/bin/MGIreg.gff3.sh | tee -a ${LOG}

TIMESTAMP=`date '+%Y%m%d.%H%M'`

#
# Archive a copy of each of the input files, adding a timestamp suffix.
#
echo "" >> ${LOG}
date >> ${LOG}
echo "Archive input files" | tee -a ${LOG}
if [ ${PROVIDER} = "ensembl" ]
then
for FILE in ${GM_FILE_DEFAULT} ${ASSOC_FILE_DEFAULT} ${TRANSCRIPT_FILE_DEFAULT} ${PROTEIN_FILE_DEFAULT} ${LOGDIR}
do
    ARC_FILE=`basename ${FILE}`.${TIMESTAMP}
    rm -rf ${ARCHIVEDIR}/${ARC_FILE}
    cp -r ${FILE} ${ARCHIVEDIR}/${ARC_FILE}
    chmod -f 777 ${ARCHIVEDIR}/${ARC_FILE}
done
fi
if [ ${PROVIDER} = "ncbi" ]
then
for FILE in ${GM_FILE_DEFAULT} ${ASSOC_FILE_DEFAULT} ${PROTEIN_FILE_DEFAULT} ${LOGDIR}
do
    ARC_FILE=`basename ${FILE}`.${TIMESTAMP}
    rm -rf ${ARCHIVEDIR}/${ARC_FILE}
    cp -r ${FILE} ${ARCHIVEDIR}/${ARC_FILE}
    chmod -f 777 ${ARCHIVEDIR}/${ARC_FILE}
done
fi
if [ ${PROVIDER} = "ensemblreg" ]
then
for FILE in ${GM_FILE_DEFAULT} ${ASSOC_FILE_DEFAULT} ${LOGDIR}
do
    ARC_FILE=`basename ${FILE}`.${TIMESTAMP}
    rm -rf ${ARCHIVEDIR}/${ARC_FILE}
    cp -r ${FILE} ${ARCHIVEDIR}/${ARC_FILE}
    chmod -f 777 ${ARCHIVEDIR}/${ARC_FILE}
done
fi
if [ ${PROVIDER} = "vistareg" ]
then
for FILE in ${GM_FILE_DEFAULT} ${ASSOC_FILE_DEFAULT} ${LOGDIR}
do
    ARC_FILE=`basename ${FILE}`.${TIMESTAMP}
    rm -rf ${ARCHIVEDIR}/${ARC_FILE}
    cp -r ${FILE} ${ARCHIVEDIR}/${ARC_FILE}
    chmod -f 777 ${ARCHIVEDIR}/${ARC_FILE}
done
fi

#
# Touch the "lastrun" file to note when the load was run.
#
touch ${LASTRUN_FILE}

# If reloading gene models, remove lastrun so that the snpcacheload will run from the Pipeline
if [ ${RELOAD_GENEMODELS} = "true" ]
then
# Remove snpcacheload/output/lastrun so that the snpcacheload will run from the Pipeline
case `uname -n` in
bhmgiapp01)
       echo "removing mgiadmin@bhmgidb03lp rm -rf /data/loads/mgi/snpcacheload/output/lastrun" | tee -a ${LOG}
       ssh mgiadmin@bhmgidb03lp 'rm -rf /data/loads/mgi/snpcacheload/output/lastrun'
       ;;
bhmgidevapp01)
       echo "removing mgiadmin@bhmgidb05ld rm -rf /data/loads/mgi/snpcacheload/output/lastrun" | tee -a ${LOG}
       ssh mgiadmin@bhmgidb05ld 'rm -rf /data/loads/mgi/snpcacheload/output/lastrun'
       ;;
*) ;;
esac
fi

#
# mail the log
#
cat ${LOG} | mailx -s "Gene Model Load Completed: ${PROVIDER}" ${MAIL_LOG}

exit 0
