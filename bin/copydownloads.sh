#!/bin/sh

#
# 1) copy bhmgiapp01:/data/downloads files to development server
# 2) copy TRDIR genemodel and assoc files to development server
#
# Usage: copydownloads.sh ensembl/ncbi/ensemblreg/vistareg
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
elif [ "`echo $1 | grep -i '^ensemblreg$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_ensemblreg.config
elif [ "`echo $1 | grep -i '^vistareg$'`" != "" ]
then
        CONFIG=${GENEMODELLOAD}/genemodel_vistareg.config
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
rm -rf /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/cdna/${TRANSCRIPT_FILE_NAME}
rm -rf /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/pep/${PROTEIN_FILE_NAME}
rm -rf /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/ncrna/${NCRNA_FILE_NAME}
scp bhmgiapp01:/data/downloads/ftp.ensembl.org/pub/current_regulation/mus_musculus/mus_musculus.GRCm39.Regulatory_Build.regulatory_features.20240230.gff.gz /data/downloads/ftp.ensembl.org/pub/current_regulation/mus_musculus/
scp bhmgiapp01:/data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/cdna/${TRANSCRIPT_FILE_NAME} /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/cdna
scp bhmgiapp01:/data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/pep/${PROTEIN_FILE_NAME} /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/pep
scp bhmgiapp01:/data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/ncrna/${NCRNA_FILE_NAME} /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/ncrna
ls -l /data/downloads/ftp.ensembl.org/pub/current_regulation/mus_musculus/mus_musculus.GRCm39.Regulatory_Build.regulatory_features.20240230.gff.gz
ls -l /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/cdna/${TRANSCRIPT_FILE_NAME}
ls -l /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/pep/${PROTEIN_FILE_NAME}
ls -l /data/downloads/ftp.ensembl.org/pub/current_fasta/mus_musculus/ncrna/${NCRNA_FILE_NAME}

cp -r ${TRDIR}/GeneModelLoad/ensembl_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/AssociationLoad/ensembl_assoc.txt ${INPUTDIR}
ls -l ${INPUTDIR}/ensembl_genemodels.txt
ls -l  ${INPUTDIR}/ensembl_assoc.txt

elif [ "${GM_PROVIDER}" = "NCBI" ]
then
#
# ncbi/entrezgene
#
cp -r ${TRDIR}/GeneModelLoad/ncbi_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/AssociationLoad/ncbi_assoc.txt ${INPUTDIR}
ls -l ${INPUTDIR}/ncbi_genemodels.txt
ls -l ${INPUTDIR}/ncbi_assoc.txt

elif [ "${GM_PROVIDER}" = "EnsemblReg" ]
then
#
# ensembl regulatory
#
cp -r ${TRDIR}/GeneModelLoad/ensemblreg_genemodels.txt ${INPUTDIR}
cp -r ${TRDIR}/AssociationLoad/ensemblreg_assoc.txt ${INPUTDIR}
ls -l ${INPUTDIR}/ensemblreg_genemodels.txt
ls -l ${INPUTDIR}/ensemblreg_assoc.txt

elif [ "${GM_PROVIDER}" = "VISTAReg" ]
then
#
# vista regulatory
#
cp -r ${TRDIR}/GeneModelLoad/VISTA_genemodels.txt ${INPUTDIR}/vistareg_genemodels.txt
cp -r ${TRDIR}/AssociationLoad/MGI_VISTA_association_load ${INPUTDIR}/vistareg_assoc.txt
ls -l ${INPUTDIR}/vistareg_genemodels.txt
ls -l ${INPUTDIR}/vistareg_assoc.txt

else
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi

rm -rf ${DATADOWNLOADS}/ftp.ensembl.org/pub/current_regulation/mus_musculus/mus_musculus.GRCm39.Regulatory_Build.regulatory_features.20240230.gff.gz
rm -rf ${DATADOWNLOADS}/ftp.ncbi.nih.gov/genomes/refseq/vertebrate_mammalian/Mus_musculus/annotation_releases/GCF_000001635.27-RS_2024_02/GCF_000001635.27_GRCm39_genomic.gff.gz
scp bhmgiapp01:${DATADOWNLOADS}/ftp.ensembl.org/pub/current_regulation/mus_musculus/mus_musculus.GRCm39.Regulatory_Build.regulatory_features.20240230.gff.gz ${DATADOWNLOADS}/ftp.ensembl.org/pub/current_regulation/mus_musculus/
scp bhmgiapp01:${DATADOWNLOADS}/ftp.ncbi.nih.gov/genomes/refseq/vertebrate_mammalian/Mus_musculus/annotation_releases/GCF_000001635.27-RS_2024_02/GCF_000001635.27_GRCm39_genomic.gff.gz ${DATADOWNLOADS}/ftp.ncbi.nih.gov/genomes/refseq/vertebrate_mammalian/Mus_musculus/annotation_releases/GCF_000001635.27-RS_2024_02
ls -l ${DATADOWNLOADS}/ftp.ensembl.org/pub/current_regulation/mus_musculus/mus_musculus.GRCm39.Regulatory_Build.regulatory_features.20240230.gff.gz
ls -l ${DATADOWNLOADS}/ftp.ncbi.nih.gov/genomes/refseq/vertebrate_mammalian/Mus_musculus/annotation_releases/GCF_000001635.27-RS_2024_02/GCF_000001635.27_GRCm39_genomic.gff.gz

#touch ${LASTDOWNLOAD_FILE}

date

