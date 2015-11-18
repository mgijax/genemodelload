#!/bin/sh

#
# there are 7 steps to this process
#
# step 1 : 
#	nomenload
# 	mcvload
# 	update /mgi/all/wts_projects/10300/10308/RawBioTypeEquivalence/biotypemap.txt
#
# step 2
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
# vega:
# 	genemodelload/genemodel_vega.config
# 	assemblyseqload/vega_assemblyseqload.config
# 	vega_ensemblseqload/vega_proteinseqload.config
# 	vega_ensemblseqload/vega_transcriptseqload.config
#

#
#  If the MGICONFIG environment variable does not have a local override,
#  use the default "test" settings.
#
if [ "${MGICONFIG}" = "" ]
then
    MGICONFIG=/usr/local/mgi/scrum-dog/mgiconfig
    export MGICONFIG
fi

#
# $1 = GM_PROVIDER config file
# genemodel_ensembl.config, genemodel_ncbi.config, genemodel_vega.config
#
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
	echo "\nserver verified as a test server...continuing..."
else
 	echo "\ncannot run the test on this server : "
	exit 1
fi

#
# reset $HOME/.pgpass file to use the dev version
#
echo "\nsetting postgres password..."
${MGIBIN}/pgsetup
cat ${HOME}/.pgpass

#
# step 3
#
# copy produciton /download files to test server
# only need to do this once per TR
#./copydownloads.sh $1

# step 4
#
# copy downloads files to genemodeload/input directory
# copy sophia's .txt files to genemodelload/input directory
# only need to do this once per TR
./copyinputs.sh $1

#
# step 5
#
# reload the database
#
echo "\nloading test database...."
${PG_DBUTILS}/bin/loadDB.csh ${PG_DBSERVER} ${PG_DBNAME} ${TEST_DBSCHEMA} ${TEST_DBDUMP}
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo "error : cannot load database : "
	echo  ${PG_DBSERVER}, ${PG_DBNAME}, ${TEST_DBDUMP_TO}
fi
exit 0

#
# step 6
#
# run the genemodelload
# 
echo "\nrunning ${GENEMODELLOAD}/bin/genemodelload.sh ", ${GM_PROVIDER}
if [ "${GM_PROVIDER}" = "Ensembl" ]
then
  rm -rf ${INPUTDIR}/Ensembl.lastrun
  ${GENEMODELLOAD}/bin/genemodelload.sh ensembl
elif [ "${GM_PROVIDER}" = "VEGA" ]
then
  rm -rf ${INPUTDIR}/VEGA.lastrun
  ${GENEMODELLOAD}/bin/genemodelload.sh vega
elif [ "${GM_PROVIDER}" = "NCBI" ]
then
  rm -rf ${INPUTDIR}/NCBI.lastrun
  ${GENEMODELLOAD}/bin/genemodelload.sh ncbi
else
    echo "\nvariable GM_PROVIDER has not been set"
    exit 1
fi
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo "\nerror : genemodelload failed"
fi
exit 0

#
# step 7
#
# run all cache updates
#
echo "\nrunning ${SEQCACHELOAD}/seqcoord.csh ", ${GM_PROVIDER}
${SEQCACHELOAD}/seqcoord.csh
echo "\nrunning ${SEQCACHELOAD}/marker.csh ", ${GM_PROVIDER}
${SEQCACHELOAD}/seqmarker.csh
echo "\nrunning ${MRKCACHELOAD}/mrklabel.csh ", ${GM_PROVIDER}
${MRKCACHELOAD}/mrklabel.csh
echo "\nrunning ${MRKCACHELOAD}/mrkref.csh ", ${GM_PROVIDER}
${MRKCACHELOAD}/mrkref.csh
echo "\nrunning ${MRKCACHELOAD}/mrklocation.csh ", ${GM_PROVIDER}
${MRKCACHELOAD}/mrklocation.csh

#
# contact MGI-SE-Admin : load EMBOSS sequences
# wiki : sw:Emboss
#
date

