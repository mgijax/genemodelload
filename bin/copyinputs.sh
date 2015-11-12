#!/bin/sh

#
# primarily for testing purposes...
#
# 1) curator : copy bhmgiapp01:/data/downloads files to test server
# 2) SE : manually copy backup file into TEST_DBDUMP
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
cp /data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp /data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME} ${TRANSCRIPT_FILE_DEFAULT}
cp /data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME} ${PROTEIN_FILE_DEFAULT}
cp /data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME} ${NCRNA_FILE_DEFAULT}
cp ${TRDIR}/GeneModelLoad/ensembl_genemodels.txt ${INPUTDIR}
cp ${TRDIR}/AssociationLoad/ensembl_assoc.txt ${INPUTDIR}

elif [ "${GM_PROVIDER}" = "VEGA" ]
then
#
# vega
#
cp /data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp /data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME} ${TRANSCRIPT_FILE_DEFAULT}
cp /data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME} ${PROTEIN_FILE_DEFAULT}
cp ${TRDIR}/VEGA/GeneModelLoad/vega_genemodels.txt ${INPUTDIR}
cp ${TRDIR}/VEGA/AssociationLoad/vega_assoc.txt ${INPUTDIR}

elif [ "${GM_PROVIDER}" = "NCBI" ]
then
#
# ncbi/entrezgene
#
cp /data/downloads/entrezgene/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp ${TRDIR}/VEGA/GeneModelLoad/ncbi_genemodels.txt ${INPUTDIR}
cp ${TRDIR}/VEGA/AssociationLoad/ncbi_assoc.txt ${INPUTDIR}

else
then
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

date |tee -a $LOG

