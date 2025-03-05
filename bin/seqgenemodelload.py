##########################################################################
#
# Purpose:
#       creates bcp file for SEQ_GeneModel for a given provider
#
Usage='createSeqGeneModelInput.py inputFile (ensembl | ncbi | ensemblreg | vistareg)'
#
# Env Vars:
#    1. BCP_FILE_PATH
#	 2. PROVIDER_LOGICALDB
#	 3. USERKEY
#
# Inputs: 
#	1. mgd database to resolve gmId to sequence key and translate raw biotype to _MarkerType_key 
#   2. input file from GM_FILE_DEFAULT, which maps gmId to raw biotype (column 1,7)
#
# Outputs:
#	 1. SEQ_GeneModel bcp file, tab-delimited
#       1. _Sequence_key
#	    2. _GMMarkerType_key
#	    3. raw biotype 
#	    4. exonCount (null)
#	    5. transcriptCount (null)
#	    6. _CreatedBy_key
#	    7. _ModifiedBy_key
#	    8. creation_date
#	    9. modification_date
#
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
#  03/04/2025  lec  added loadEnsemblRegRawBioTypeByGMIDLookup
#   input file for ensemblreg has changed
#
#  04/14/2023  sc   Update to parse ensemblreg raw biotypes
#
#  01/20/2010  sc   Initial development
#
###########################################################################

import sys
import os
import mgi_utils
import db

db.setTrace()

#
# CONSTANTS 
#
TAB= '\t'
CRT = '\n'
SPACE = ' '
SCOLON = ';'

# MGI_User key for the load
CREATEDBY_KEY = os.environ['USERKEY']

#
# GLOBALS
#

# bcp file path
bcpFilePath = ''

# file descriptors
inFile = ''
bcpFile = ''

# timestamp for creation/modification date
cdate = mgi_utils.date('%m/%d/%Y')      # current date

#
# lookups
#
# loaded from provider input file - maps gene model ID to raw biotype
rawBioTypeByGMIDLookup = {}     # {gmId:rawBioType, ...}

# loaded from db translation query - maps raw biotype to _MarkerType_key
markerTypeKeyByRawBioTypeLookup = {} # {rawBioType:_MarkerType_key}

# loaded from db by provider - maps a gmId to its _Sequence_key(s) i
# Only NCBI has multiple sequences per gmID
seqKeyByGMIDLookup = {} # {gmId:list of seqKeys, ...}

# Purpose:  Load biotype translation Lookup; Lookup raw biotype to get MGI Marker Type Key
# Returns: nothing
# Assumes: there is a connection to the database
# Effects: nothing 
# Throws: nothing

def loadMarkerTypeKeyLookup():
    global markerTypeKeyByRawBioTypeLookup

    print("loadMarkerTypeKeyLookup()")

    # load the biotype translation into a lookup
    results = db.sql('''
        select distinct t.term, m._Marker_Type_key from MRK_BiotypeMapping m, VOC_Term t where m._biotypeterm_key = t._Term_key
        ''', 'auto')
    for r in results:
        markerTypeKeyByRawBioTypeLookup[r['term']] = r['_Marker_Type_key']
    #print(markerTypeKeyByRawBioTypeLookup_

# Purpose:  Load sequence key lookup by seqId for a given provider
# Returns: nothing
# Assumes: there is a connection to the database
# Effects: nothing
# Throws: nothing

def loadSequenceKeyLookup():
    global seqKeyByGMIDLookup

    print('loadSequenceKeyLookup() : ' + os.environ['PROVIDER_LOGICALDB'])

    ldbName =  os.environ['PROVIDER_LOGICALDB']
    results = db.sql('''select _LogicalDB_key from ACC_LogicalDB where name = '%s' ''' % ldbName, 'auto')
    if len(results) == 0:
        print('LogicalDB name not in database: %s' % ldbName)
        sys.exit(1)
    ldbKey = results[0]['_LogicalDB_key']
    results = db.sql('''
        select accId, _Object_key as seqKey
        from ACC_Accession
        where _MGIType_key = 19
        and _LogicalDB_key = %s
        and preferred = 1
        ''' % ldbKey, 'auto')
    for r in results:
        if r['accId'] not in seqKeyByGMIDLookup:
            seqKeyByGMIDLookup[r['accId']] = []
        seqKeyByGMIDLookup[r['accId']].append(r['seqKey'])
    #print(seqKeyByGMIDLookup)

# Purpose: Initialize globals; load lookups 
# Returns: nothing
# Assumes: nothing
# Effects: nothing
# Throws: nothing

def init():
    global inFile, bcpFilePath, bcpFile

    print('%s' % mgi_utils.date())
    print('Initializing')

    if len(sys.argv) != 2:
            print(Usage)
            sys.exit(1)

    inFile = open(sys.argv[1], 'r')

    try:
        bcpFilePath = os.environ['BCP_FILE_PATH']
        bcpFile = open(bcpFilePath, 'w')
    except:
        print('Could not open file for writing %s\n') % bcpFilePath 
        sys.exit(1)

    for line in inFile.readlines():
        columnList = str.split(line[:-1], TAB)
        gmId = columnList[0]
        biotype = columnList[6]
        rawBioTypeByGMIDLookup[gmId] = biotype

    loadSequenceKeyLookup()
    loadMarkerTypeKeyLookup()

# Purpose: create the bcp file
# Returns: nothing
# Assumes: nothing
# Effects: creates file in the filesystem
# Throws: nothing

def run ():

    print('Creating bcp file')

    # current count of gm IDs found in database, but not in input
    notInInputCtr = 0

    # current count of gm IDs found in database, but input raw biotype
    # will not translate
    noTranslationCtr = 0

    for gmId in list(seqKeyByGMIDLookup.keys()):

        seqKeyList = seqKeyByGMIDLookup[gmId]
        for seqKey in seqKeyList:
            if gmId in rawBioTypeByGMIDLookup:
                rawBioType = rawBioTypeByGMIDLookup[gmId]
            else:
                print('%s is not in the input file' % gmId)
                notInInputCtr = notInInputCtr + 1
                continue

            if rawBioType in markerTypeKeyByRawBioTypeLookup:
                markerTypeKey = markerTypeKeyByRawBioTypeLookup[rawBioType]
            else:
                print('GM ID %s raw biotype %s has no translation in the database' % (gmId, rawBioType))
                noTranslationCtr = noTranslationCtr + 1
                continue

            bcpFile.write('%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s' % \
                (seqKey, TAB, markerTypeKey, TAB, rawBioType, TAB, \
                    TAB, TAB, CREATEDBY_KEY, TAB, CREATEDBY_KEY, TAB, cdate, TAB, cdate, CRT) )

    print('\n%s gene model Ids in the database but not in the input file' % (notInInputCtr))
    print('\n%s gene model Ids not loaded because unable to translate biotype\n' % (noTranslationCtr))

#
# Main
#

init()
run()
inFile.close()
bcpFile.close()
