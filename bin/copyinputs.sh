#!/bin/sh

#
# 1) copy /data/downloads files to /data/loads/mgi/genemodelload/input directory
# 2) copy TR files to /data/loads/mgi/genemodelload/input directory
#
# Usage: copyinputs.sh ensembl/ncbi/ensemblseq/vistareg
#
if [ "${MGICONFIG}" = "" ]
then
    MGICONFIG=/usr/local/mgi/live/mgiconfig
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
elif [ "`echo $1 | grep -i '^ensemblreg$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_ensemblreg.config
elif [ "`echo $1 | grep -i '^vistareg$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_vistareg.config
else
        echo ${USAGE}; exit 1
fi

. ${CONFIG}

date

#
# The following steps must all be done on the TEST SERVER: 
#
#if [ "${INSTALL_TYPE}" = "dev" ]
#then
#        echo "server verified as a test server...continuing..."
#else
#        echo "cannot run the test on this server : "
#        exit 1
#fi

#
# copy input files from TR directory to genemodelload input directory
#
echo "copy input files from TR directory to /data/loads/mgi/genemodelload/input directory..."

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

elif [ "${GM_PROVIDER}" = "NCBI" ]
then
#
# ncbi/entrezgene
#
cp -r /data/downloads/entrezgene/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp -r ${TRDIR}/GeneModelLoad/ncbi_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/AssociationLoad/ncbi_assoc.txt ${INPUTDIR}

#elif [ "${GM_PROVIDER}" = "EnsemblReg" ]
#then
#
# ensembl regulatory
#
#cp -r /data/downloads/ensembl_mus_regulatory/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
#cp -r ${TRDIR}/GeneModelLoad/????_genemodels.txt ${INPUTDIR}
#cp -r ${TRDIR}/AssociationLoad/????_assoc.txt ${INPUTDIR}

elif [ "${GM_PROVIDER}" = "VISTAReg" ]
then
#
# vista regulatory
#
cp -r ${TRDIR}/GeneModelLoad/VISTA_genemodels.txt ${INPUTDIR}/vistareg_genemodels.txt
cp -r ${TRDIR}/AssociationLoad/MGI_VISTA_association_load ${INPUTDIR}/vistareg_assoc.txt

else
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

ls -l ${INPUTDIR}

date

