#!/bin/sh

#
# run the gene model load cache scripts
#

if [ "${MGICONFIG}" = "" ]
then
    MGICONFIG=/usr/local/mgi/live/mgiconfig
    export MGICONFIG
fi

. ${MGICONFIG}/master.config.sh

echo -e "\nrunning ${SEQCACHELOAD}/seqcoord.csh"
${SEQCACHELOAD}/seqcoord.csh
echo -e "\nrunning ${SEQCACHELOAD}/seqmarker.csh"
${SEQCACHELOAD}/seqmarker.csh
echo -e "\nrunning ${MRKCACHELOAD}/mrklabel.csh"
${MRKCACHELOAD}/mrklabel.csh
echo -e "\nrunning ${MRKCACHELOAD}/mrkref.csh"
${MRKCACHELOAD}/mrkref.csh
echo -e "\nrunning ${MRKCACHELOAD}/mrklocation.csh"
${MRKCACHELOAD}/mrklocation.csh

date

