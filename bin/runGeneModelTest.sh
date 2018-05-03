#!/bin/sh

#
# there are 7 steps to this process
#
# step 1 : 
#	nomenload
# 	mcvload
# 	update /mgi/all/wts_projects/10300/10308/RawBioTypeEquivalence/biotypemap.txt
#
# step 2 :
#
# edit these configuration values:
#
# TRDIR				/mgi/all/wts_projects/?/?
# BIOTYPE_FILE_NAME		genemodelload
# TRANSCRIPT_FILE_NAME		genemodelload
# PROTEIN_FILE_NAME		genemodelload
# NCRNA_FILE_NAME		genemodelload
# RELOAD_GENEMODELS=true 	genemodelload
# SEQ_RELEASE_DATE		assemblyseqload, vega_ensemblseqload
#
# ensembl:
# 	genemodelload/genemodel_ensembl.config
# 	assemblyseqload/ensembl_assemblyseqload.config
# 	vega_ensemblseqload/ensembl_proteinseqload.config
# 	vega_ensemblseqload/ensembl_transcriptseqload.config
#
# ncbi:
# 	assemblyseqload/ncbi_assemblyseqload.config
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

#
# $1 = GM_PROVIDER config file
# genemodel_ensembl.config, genemodel_ncbi.config
#
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

. ${CONFIG}

date

#
# The following steps must all be done on the TEST SERVER: 
#
if [ "${INSTALL_TYPE}" = "dev" ]
then
	echo -e "\nserver verified as a test server...continuing..."
else
 	echo -e "\ncannot run the test on this server : "
	exit 1
fi

#
# set $HOME/.pgpass to use the dev password version
#
echo -e "\nsetting postgres password..."
${MGIBIN}/pgsetup
cat ${HOME}/.pgpass

#
# step 3
#
# reload the database
#
echo -e "\nloading test database...."
${PG_DBUTILS}/bin/loadDB.csh ${PG_DBSERVER} ${PG_DBNAME} ${TEST_DBSCHEMA} ${TEST_DBDUMP}
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo -e "\nerror : cannot load database : "
	echo  ${PG_DBSERVER}, ${PG_DBNAME}, ${TEST_DBDUMP_TO}
	exit 1
fi

#
# step 4
#
# copy produciton /download files to test server
# only need to do this once per TR
./copydownloads.sh $1

# step 5
# copy .txt files to genemodelload/input directory
# only need to do this once per TR
echo -e "\nremoving all ${DATALOADSOUTPUT} files...."
rm -rf ${ARCHIVEDIR}/*
rm -rf ${INPUTDIR}/*
rm -rf ${OUTPUTDIR}/*
rm -rf ${LOGDIR}/*
rm -rf ${RPTDIR}/*
./copyinputs.sh $1

#
# step 6
#
# run the genemodelload
# 
echo -e "\nrunning ${GENEMODELLOAD}/bin/genemodelload.sh ", ${GM_PROVIDER}
if [ "${GM_PROVIDER}" = "Ensembl" ]
then
  ${GENEMODELLOAD}/bin/genemodelload.sh ensembl
elif [ "${GM_PROVIDER}" = "NCBI" ]
then
  ${GENEMODELLOAD}/bin/genemodelload.sh ncbi
else
    echo -e "\nvariable GM_PROVIDER has not been set"
    exit 1
fi
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo -e "\nerror : genemodelload failed"
	exit 1
fi

#
# step 7
#
# run all cache updates
#
./runGeneModelCache.sh

#
# contact MGI-SE-Admin : load EMBOSS sequences
# wiki : sw:Emboss
#
date

