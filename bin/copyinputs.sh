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
# copy input files from TR directory to test server
#
echo "copy input files from TR directory to test serve..."

if [ "${GM_PROVIDER}" = "Ensembl" ]
then
#
# ensembl
#
cp -r /data/downloads/ensembl_mus_gtf/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp -r /data/downloads/ensembl_mus_cdna/${TRANSCRIPT_FILE_NAME} ${TRANSCRIPT_FILE_DEFAULT}
cp -r /data/downloads/ensembl_mus_protein/${PROTEIN_FILE_NAME} ${PROTEIN_FILE_DEFAULT}
cp -r /data/downloads/ensembl_mus_ncrna/${NCRNA_FILE_NAME} ${NCRNA_FILE_DEFAULT}
cp -r ${TRDIR}/GeneModelLoad/ensembl_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/AssociationLoad/ensembl_assoc.txt ${INPUTDIR}

elif [ "${GM_PROVIDER}" = "VEGA" ]
then
#
# vega
#
cp -r /data/downloads/vega_mus_gtf/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp -r /data/downloads/vega_mus_cdna/${TRANSCRIPT_FILE_NAME} ${TRANSCRIPT_FILE_DEFAULT}
cp -r /data/downloads/vega_mus_protein/${PROTEIN_FILE_NAME} ${PROTEIN_FILE_DEFAULT}
cp -r ${TRDIR}/VEGA/GeneModelLoad/vega_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/VEGA/AssociationLoad/vega_assoc.txt ${INPUTDIR}

elif [ "${GM_PROVIDER}" = "NCBI" ]
then
#
# ncbi/entrezgene
#
cp -r /data/downloads/entrezgene/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp -r ${TRDIR}/VEGA/GeneModelLoad/ncbi_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/VEGA/AssociationLoad/ncbi_assoc.txt ${INPUTDIR}

else
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

ls -l ${INPUTDIR}

date

