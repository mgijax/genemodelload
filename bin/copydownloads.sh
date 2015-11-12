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
. $1

LOG=$0.log
rm -rf ${LOG}
touch ${LOG}

date |tee -a $LOG

#
# The following steps must all be done on the TEST SERVER: 
#
case `uname -n` in

        bhmgidevapp01|mgi-testdb4)
                echo "server verified as a test server...continuing..."
                ;;

        *)
                echo "cannot run the test on this server : " 
                echo `uname -n` 
                ;;
esac

#
# copy download files from production server to test server
#

if [ "${GM_PROVIDER}" = "Ensembl" ]
then
#
# ensembl
#
scp -p bhmgiapp01:/data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME} /data/downloads/ensembl_mus_gtf
scp -p bhmgiapp01:/data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME} /data/downloads/ensembl_mus_cdna
scp -p bhmgiapp01:/data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME} /data/downloads/ensembl_mus_protein
scp -p bhmgiapp01:/data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME} /data/downloads/ensembl_mus_ncrna
ls -l /data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME}
ls -l /data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME}
ls -l /data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME}
ls -l /data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME}

elif [ "${GM_PROVIDER}" = "VEGA" ]
then
#
# vega
#
scp -p bhmgiapp01:/data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME} /data/downloads/vega_mus_gtf
scp -p bhmgiapp01:/data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME} /data/downloads/vega_mus_cdna
scp -p bhmgiapp01:/data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME} /data/downloads/vega_mus_protein
ls -l /data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME}
ls -l /data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME}
ls -l /data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME}

elif [ "${GM_PROVIDER}" = "NCBI" ]
then
#
# ncbi/entrezgene
#
scp -p bhmgiapp01:/data/downloads/entrezgene/${BIOTYPE_FILE_NAME} /data/downloads/entrezgene
ls -l /data/downloads/entrezgene/${BIOTYPE_FILE_NAME}

else
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

date |tee -a $LOG

