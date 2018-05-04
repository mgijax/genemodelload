#!/bin/sh

#
# 1) copy bhmgiapp01:/data/downloads files to development server
#

#
#  If the MGICONFIG environment variable does not have a local override,
#  use the default "test" settings.
#
if [ "${MGICONFIG}" = "" ]
then
    MGICONFIG=/usr/local/mgi/live/mgiconfig
    export MGICONFIG
fi


echo 'configuration ${MGICONFIG}/master.config.sh'
. ${MGICONFIG}/master.config.sh
. ${GENEMODELLOAD}/genemodel_common.config

if [ "`echo $1 | grep -i '^ensembl$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_ensembl.config
elif [ "`echo $1 | grep -i '^ncbi$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_ncbi.config
else
	echo ${USAGE}; exit 1
fi

echo 'configuration ${CONFIG}'
. ${CONFIG}

date

#
# The following steps must all be done on the TEST SERVER: 
#
if [ "${INSTALL_TYPE}" = "dev" ]
then
        echo "server verified as a test server...continuing..."
else
        echo "cannot run the test on this server : "
        exit 1
fi

#LASTDOWNLOAD_FILE=${INPUTDIR}/${GM_PROVIDER}.lastdownload
#if [ -f ${LASTDOWNLOAD_FILE} ]
#then
#    if test ${LASTDOWNLOAD_FILE} -nt ${ASSOC_FILE_DEFAULT}
#    then
#        echo "download file has not been updated - will not copy any download files" | tee -a ${LOG}
#        exit 0
#    fi  
#fi

#
# copy download files from production server to test server
#
echo "copying download files from production server to development server...."

if [ "${GM_PROVIDER}" = "Ensembl" ]
then
#
# ensembl
#
rm -rf /data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME}
rm -rf /data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME}
rm -rf /data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME}
rm -rf /data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME}
scp bhmgiapp01:/data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME} /data/downloads/ensembl_mus_gtf
scp bhmgiapp01:/data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME} /data/downloads/ensembl_mus_cdna
scp bhmgiapp01:/data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME} /data/downloads/ensembl_mus_protein
scp bhmgiapp01:/data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME} /data/downloads/ensembl_mus_ncrna
ls -l /data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME}
ls -l /data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME}
ls -l /data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME}
ls -l /data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME}

elif [ "${GM_PROVIDER}" = "NCBI" ]
then
#
# ncbi/entrezgene
#
rm -rf /data/downloads/entrezgene/${BIOTYPE_FILE_NAME}
scp bhmgiapp01:/data/downloads/entrezgene/${BIOTYPE_FILE_NAME} /data/downloads/entrezgene
ls -l /data/downloads/entrezgene/${BIOTYPE_FILE_NAME}

else
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

#touch ${LASTDOWNLOAD_FILE}

date

