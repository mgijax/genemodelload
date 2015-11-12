#!/bin/sh

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
    MGICONFIG=/usr/local/mgi/test/mgiconfig
    export MGICONFIG
fi

#
# $1 = GM_PROVIDER config file
# genemodel_ensembl.config, genemodel_ncbi.config, genemodel_vega.config
#
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
# step 3
#
# copy produciton /download files to test server
# only need to do this once per TR
#./copydownloads.sh $1
#

# step 4
#
# copy downloads files to genemodeload/input directory
# copy sophia's .txt files to genemodelload/input directory
# only need to do this once per TR
#./copyinputs.sh $1
#

#
# step 5
#
# reload the database
#
if [ ! -d ${TEST_DBDUMP} ]
then
	echo "error : cannot find database dump : ", ${TEST_DBDUMP} | tee -a ${LOG}
	exit 1
fi

echo "loading test database...."
echo ${PG_DBUTILS}/bin/loadDB.csh ${PG_DBSERVER} ${PG_DBNAME} mgd ${TEST_DBDUMP} | tee -a ${LOG}
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo "error : cannot load database : ", ${PG_DBSERVER}, ${PG_DBNAME}, ${TEST_DBDUMP_TO} | tee -a ${LOG}
fi

#
# step 6
#
# run the genemodelload
# 
echo "Running ${GENEMODELLOAD}/bin/genemodelload.sh ", ${GM_PROVIDER} | tee -a ${LOG}
if [ "${GM_PROVIDER}" = "Ensembl" ]
then
  rm -rf ${INPUTFILE}/Ensembl.lastrun
  echo ${GENEMODELLOAD}/bin/genemodelload.sh ensembl | tee -a ${LOG}
elif [ "${GM_PROVIDER}" = "VEGA" ]
  rm -rf ${INPUTFILE}/VEGA.lastrun
  echo ${GENEMODELLOAD}/bin/genemodelload.sh vega | tee -a ${LOG}
elif [ "${GM_PROVIDER}" = "NCBI" ]
  rm -rf ${INPUTFILE}/NCBI.lastrun
  echo ${GENEMODELLOAD}/bin/genemodelload.sh ncbi | tee -a ${LOG}
else
then
    echo "variable GM_PROVIDER has not been set"
    exit 1
fi
STAT=$?
if [ ${STAT} -ne 0 ]
then
	echo "error : genemodelload failed"
fi

#
# step 7
#
# run all cache loads (see wiki/section 11/Processing)
#
#${SEQCACHELOAD}/seqcoord.csh | tee -a ${LOG}
#${SEQCACHELOAD}/seqmarker.csh | tee -a ${LOG}
#${MRKCACHELOAD}/mrklabel.csh | tee -a ${LOG}
#${MRKCACHELOAD}/mrkref.csh | tee -a ${LOG}
#${MRKCACHELOAD}/mrklocation.csh  | tee -a ${LOG}

#
# contact MGI-SE-Admin : load EMBOSS sequences
# wiki : sw:Emboss
#
date |tee -a $LOG

