#!/bin/sh

#
# there are 1 step to this process
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
# SEQ_RELEASE_DATE		assemblyseqload, ensemblseqload
#
# ensembl:
# 	genemodelload/genemodel_ensembl.config
# 	assemblyseqload/ensembl_assemblyseqload.config
# 	ensemblseqload/ensembl_proteinseqload.config
# 	ensemblseqload/ensembl_transcriptseqload.config
#
# ncbi:
# 	assemblyseqload/ncbi_assemblyseqload.config
#
# ensemblreg:
# 	genemodelload/genemodel_ensemblreg.config
# 	assemblyseqload/ensembl_assemblyseqload.config
#
# vistareg:
# 	genemodelload/genemodel_vistareg.config
# 	assemblyseqload/ensembl_assemblyseqload.config
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

date

