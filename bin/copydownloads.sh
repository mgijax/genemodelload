#!/bin/sh

#
# primarily for testing purposes...
#
# copy bhmgiapp01:/data/downloads files to test server
#

#
#  If the MGICONFIG environment variable does not have a local override,
#  use the default "test" settings.
#
if [ "${MGICONFIG}" = "" ]
then
    MGICONFIG=/usr/local/mgi/test/mgiconfig
    export MGICONFIG
fi

. ${MGICONFIG}/master.config.sh
. ${GENEMODELLOAD}/genemodel_common.config

if [ "`echo $1 | grep -i '^ensembl$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_ensembl.config
elif [ "`echo $1 | grep -i '^ncbi$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_ncbi.config
elif [ "`echo $1 | grep -i '^vega$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_vega.config
else
	echo ${USAGE}; exit 1
fi

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

#
# copy download files from production server to test server
#
echo "copying download files from production server to test server...."

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

elif [ "${GM_PROVIDER}" = "VEGA" ]
then
#
# vega
#
rm -rf /data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME}
rm -rf /data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME}
rm -rf /data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME}
scp bhmgiapp01:/data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME} /data/downloads/vega_mus_gtf
scp bhmgiapp01:/data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME} /data/downloads/vega_mus_cdna
scp bhmgiapp01:/data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME} /data/downloads/vega_mus_protein
ls -l /data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME}
ls -l /data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME}
ls -l /data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME}

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

date

