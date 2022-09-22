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
        CONFIG=${GENEMODELLOAD}/ncbi.config
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
cp -r /data/downloads/ftp.ensembl.org/pub/current_gtf/mus_musculus/${BIOTYPE_FILE_NAME} ${BIOTYPE_FILE_DEFAULT}
cp -r /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/cdna/${TRANSCRIPT_FILE_NAME} ${TRANSCRIPT_FILE_DEFAULT}
cp -r /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/pep/${PROTEIN_FILE_NAME} ${PROTEIN_FILE_DEFAULT}
cp -r /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/ncrna/${NCRNA_FILE_NAME} ${NCRNA_FILE_DEFAULT}

cp -r /data/downloads/ftp.ensembl.org/pub/current_gtf/mus_musculus/${BIOTYPE_FILE_NAME} ${INPUTDIR}/ensembl_biotypes.gz
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

elif [ "${GM_PROVIDER}" = "EnsemblReg" ]
then
#
# ensembl regulatory
#
cp -r ${TRDIR}/gtf/mus_musculus.GRCm39.Regulatory_Build.regulatory_features.20201021.gtf.gz ${INPUTDIR}/ensemblreg_biotypes.gz
cp -r ${TRDIR}/GeneModelLoad/RRensembl_genemodels.txt ${INPUTDIR}/ensemblreg_genemodels.txt
cp -r ${TRDIR}/AssociationLoad/MGI_ENSMUSR_association_load ${INPUTDIR}/ensemblreg_assoc.txt

elif [ "${GM_PROVIDER}" = "VISTAReg" ]
then
#
# vista regulatory
#
cp -r ${TRDIR}/GeneModelLoad/VISTA_genemodels.txt ${INPUTDIR}/vistareg_genemodels.txt
cp -r ${TRDIR}/AssociationLoad/MGI_VISTA_association_load ${INPUTDIR}/vistareg_assoc.txt
cp -r ${TRDIR}/gtf/VISTA_mm9_mm10_b39.gtf.gz ${INPUTDIR}/vistareg_biotypes.gz

else
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

ls -l ${INPUTDIR}

date

