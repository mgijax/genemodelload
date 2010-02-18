#!/usr/local/bin/python

##########################################################################
#
# Purpose:
#       creates bcp file for SEQ_GeneModel for a given provider
#
Usage='createSeqGeneModelInput.py provider (vega | ensembl | ncbi)'
#
# Env Vars:
#        1. BCP_FILE_PATH
#	 2. PROVIDER_LOGICALDB
# Inputs: 
#	1. mgd database to resolve gmId to sequence key and
#	      translate raw biotype to _MarkerType_key 
#       2. provider file, from stdin, mapping gmId to raw biotype
#
# Outputs:
#	 1. SEQ_GeneModel bcp file, tab-delimited
#           1. _Sequence_key
#	    3. _MarkerType_key
#	    4. raw biotype (null)
#	    5. transcriptCount (null)
# 	 2. Log file
#
# Exit Codes:
#
#      0:  Successful completion
#      1:  An exception occurred
#
#  Assumes:  Nothing
#
#  Notes:  None
#
###########################################################################
#
#  Modification History:
#
#  Date        SE   Change Description
#  ----------  ---  -------------------------------------------------------
#
#  01/20/2010  sc   Initial development
#
###########################################################################

import sys
import os
import mgi_utils
import loadlib
import string
import db

#
# CONSTANTS 
#
TAB= '\t'
CRT = '\n'
SPACE = ' '
SCOLON = ';'

# Biotype Translation Type
TRANSTYPE='Raw Biotype to Marker Type'

#
# GLOBALS
#

# bcp file path
bcpFilePath = ''

# file descriptors
inFile = ''
bcpFile = ''

#
# lookups
#
# loaded from provider input file - maps gene model ID to raw biotype
rawBioTypeByGMIDLookup = {}     # {gmId:rawBioType, ...}

# loaded from db translation query - maps raw biotype to _MarkerType_key
markerTypeKeyByRawBioTypeLookup = {} # {rawBioType:_MarkerType_key}

# loaded from db by provider - maps a gmId to its _Sequence_key
seqKeyByGMIDLookup = {} # {gmId:_Sequence_key, ...}

# Provider we are loading 'ncbi', 'ensembl', or 'vega'
provider = ''

def loadMarkerTypeKeyLookup():
    global markerTypeKeyByRawBioTypeLookup

    results = db.sql('''SELECT _TranslationType_key
        FROM MGI_TranslationType
        WHERE translationType = '%s' ''' % TRANSTYPE, 'auto')
    if len(results) == 0:
	print 'Translation type not in database: %s' % TRANSTYPE
        sys.exit(1)
    transTypeKey = results[0]['_TranslationType_key']

    results = db.sql('''SELECT badName, _Object_key as markerTypeKey
        FROM MGI_Translation
        WHERE _TranslationType_key = %s''' % transTypeKey, 'auto')
    for r in results:
        markerTypeKeyByRawBioTypeLookup[ r['badName'] ] = r['markerTypeKey']

def loadSequenceKeyLookup():
    global seqKeyByGMIDLookup

    ldbName =  os.environ['PROVIDER_LOGICALDB']
    results = db.sql('''SELECT _LogicalDB_key
		FROM ACC_LogicalDB
		WHERE name = '%s' ''' % ldbName, 'auto')
    if len(results) == 0:
        print 'LogicalDB name not in database: %s' % ldbName
        sys.exit(1)
    ldbKey = results[0]['_LogicalDB_key']
    results = db.sql('''SELECT accId, _Object_key as seqKey
                FROM ACC_Accession
                WHERE _MGIType_key = 19
                AND _LogicalDB_key = %s
                AND preferred = 1''' % ldbKey, 'auto')
    for r in results:
        seqKeyByGMIDLookup[r['accId']] = r['seqKey']

def loadVegaEnsemblRawBioTypeByGMIDLookup():
    global rawBioTypeByGMIDLookup

    for line in inFile.readlines():
        columnList =  string.split(line, TAB)
        biotype = string.strip(columnList[1])
        attributeList = string.split(columnList[8], SCOLON)
        gmId = (string.split(attributeList[0], '"'))[1].strip()
        # there are redundant id/biotype lines in the input, all IDs have the
        # same biotype for each of the redundant lines so save only one pair

        # but just in case check
        if rawBioTypeByGMIDLookup.has_key(gmId):
            b = rawBioTypeByGMIDLookup[gmId]
            if b != biotype:
                print 'Differing biotypes for %s: %s and %s' % (gmId, b, biotype
)
                sys.exit(1)
        rawBioTypeByGMIDLookup[gmId] = biotype
        #print '%s %s %s' % (gmId, biotype, CRT)


def loadNCBIRawBioTypeByGMIDLookup():
    global rawBioTypeByGMIDLookup

    # get the header
    header = inFile.readline()

    for line in inFile.readlines():
        columnList =  string.split(line, TAB)
        taxid = columnList[0]
        if string.strip(taxid) == '10090':
            gmId = columnList[1]
            biotype = columnList[9]
            rawBioTypeByGMIDLookup[gmId] = biotype

def init():
    global inFile, provider, bcpFilePath, bcpFile

    print '%s' % mgi_utils.date()
    print 'Initializing'

    inFile = sys.stdin
    if len(sys.argv) != 2:
            print Usage
            sys.exit(1)

    provider = sys.argv[1]

    try:
        bcpFilePath = os.environ['BCP_FILE_PATH']
        bcpFile = open(bcpFilePath, 'w')
    except:
        'Could not open file for writing %s\n' % bcpFilePath
        sys.exit(1)

    if provider == 'ensembl' or provider == 'vega':
        loadVegaEnsemblRawBioTypeByGMIDLookup()

    elif provider == 'ncbi':
        loadNCBIRawBioTypeByGMIDLookup()

    else:
        'Provider not recognized: %s' % provider
        sys.exit(1)
    loadSequenceKeyLookup()
    loadMarkerTypeKeyLookup()


def run ():
    # current count of gm IDs found in database, but not in input
    notInInputCtr = 0

    # current count of gm IDs found in database, but input raw biotype
    # will not translate
    noTranslationCtr = 0

    for gmId in seqKeyByGMIDLookup.keys():
	sequenceKey = seqKeyByGMIDLookup[gmId]

	if rawBioTypeByGMIDLookup.has_key(gmId):
	    rawBioType = rawBioTypeByGMIDLookup[gmId]
	else:
	    print '%s is not in the input file' % gmId
	    notInInputCtr = notInInputCtr + 1
	    continue

	if markerTypeKeyByRawBioTypeLookup.has_key(rawBioType):
	    markerTypeKey = markerTypeKeyByRawBioTypeLookup[rawBioType]
	else:
	    print 'GM ID %s raw biotype %s has no translation in the database' \
		% (gmId, rawBioType)
	    noTranslationCtr = noTranslationCtr + 1
	    continue

	bcpFile.write('%s%s%s%s%s%s%s%s' % \
	    (sequenceKey, TAB, markerTypeKey, TAB, rawBioType, TAB, TAB, CRT) )

    print '\n%s %s gene model Ids in the database but not in the input file' % \
	(notInInputCtr, provider)

    print '\n%s %s gene model Ids not loaded because unable to translate biotype\n' % (noTranslationCtr, provider)

#
# Main
#

print 'Initializing'
init()

print 'Creating bcp file for %s ' % provider
run()

inFile.close()
bcpFile.close()

