#!/usr/local/bin/python
#
#  genemodelQC.py
###########################################################################
#
#  Purpose:
#
#      This script will generate a set of QC reports for a pair of
#      gene model/association files.
#
#  Usage:
#
#      genemodelQC.py
#
#  Env Vars:
#
#      The following environment variables are set by the configuration
#      files that are sourced by the wrapper script:
#
#          MGI_PUBLICUSER
#          MGI_PUBPASSWORDFILE
#          GM_PROVIDER
#          GM_FILE
#          ASSOC_FILE
#          TEMP_GM_BCPFILE
#          TEMP_ASSOC_BCPFILE
#          TEMP_GM_TABLE
#          TEMP_ASSOC_TABLE
#          INVALID_MARKER_RPT
#          SEC_MARKER_RPT
#          MISSING_GMID_RPT
#          CHR_DISCREP_RPT
#          ASSOC_LOAD_FILE
#          ASSOC_FILE_LOGICALDB
#
#      The following environment variable is set by the wrapper script:
#
#          LIVE_RUN
#
#  Inputs:
#
#      - Gene model input file (${GM_FILE}) with the following tab-delimited
#        fields:
#
#          1) Gene Model ID
#          2) Chromosome
#          3) Start Coordinate
#          4) End Coordinate
#          5) Strand (+ or -)
#          6) Description
#
#      - Association input file (${ASSOC_FILE}) with the following
#        tab-delimited fields:
#
#          1) MGI ID for the Marker
#          2) Gene Model ID
#
#  Outputs:
#
#      - BCP file (${TEMP_GM_BCPFILE}) for loading the gene model file
#        into a temp table
#
#      - BCP file (${TEMP_ASSOC_BCPFILE}) for loading the gene model file
#        into a temp table
#
#      - Load-ready association file (${ASSOC_LOAD_FILE})
#
#      - QC report (${INVALID_MARKER_RPT})
#
#      - QC report (${SEC_MARKER_RPT})
#
#      - QC report (${MISSING_GMID_RPT})
#
#      - QC report (${CHR_DISCREP_RPT})
#
#  Exit Codes:
#
#      0:  Successful completion
#      1:  An exception occurred
#      2:  Discrepancy errors detected in the input files
#
#  Assumes:
#
#      This script assumes that the wrapper script has already created the
#      tables in tempdb for loading the input records into. The table
#      names are defined by the environment variables ${TEMP_GM_TABLE} and
#      ${TEMP_ASSOC_TABLE}. The wrapper script will also take care of
#      dropping the table after this script terminates.
#
#  Implementation:
#
#      This script will perform following steps:
#
#      1) Perform initialization steps.
#      2) Open the input/output files.
#      3) Load the records from the input files into the temp tables.
#      4) Generate the QC reports.
#      5) Close the input/output files.
#      6) If this is a "live" run, create the load-ready association file
#         from the associations that do not have any discrepancies.
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
#  09/08/2008  DBM  Initial development
#
###########################################################################

import sys
import os
import string
import re
import mgi_utils
import db

#
#  CONSTANTS
#
TAB = '\t'
NL = '\n'

#
#  GLOBALS
#
user = os.environ['MGI_PUBLICUSER']
passwordFile = os.environ['MGI_PUBPASSWORDFILE']

provider = os.environ['GM_PROVIDER']
liveRun = os.environ['LIVE_RUN']

gmFile = os.environ['GM_FILE']
assocFile = os.environ['ASSOC_FILE']

gmBCPFile = os.environ['TEMP_GM_BCPFILE']
assocBCPFile = os.environ['TEMP_ASSOC_BCPFILE']
gmTempTable = os.environ['TEMP_GM_TABLE']
assocTempTable = os.environ['TEMP_ASSOC_TABLE']

invMrkRptFile = os.environ['INVALID_MARKER_RPT']
secMrkRptFile = os.environ['SEC_MARKER_RPT']
missGMRptFile = os.environ['MISSING_GMID_RPT']
chrDiscrepRptFile = os.environ['CHR_DISCREP_RPT']

assocLoadFile = os.environ['ASSOC_LOAD_FILE']
logicalDB = os.environ['ASSOC_FILE_LOGICALDB']

timestamp = mgi_utils.date()

errorCount = 0

assoc = {}


#
# Purpose: Perform initialization steps.
# Returns: Nothing
# Assumes: Nothing
# Effects: Sets global variables.
# Throws: Nothing
#
def init ():
    db.set_sqlUser(user)
    db.set_sqlPasswordFromFile(passwordFile)

    return


#
# Purpose: Open the files.
# Returns: Nothing
# Assumes: Nothing
# Effects: Sets global variables.
# Throws: Nothing
#
def openFiles ():
    global fpGM, fpAssoc, fpGMBCP, fpAssocBCP
    global fpInvMrkRpt, fpSecMrkRpt, fpMissGMRpt, fpChrDiscrepRpt

    #
    # Open the input files.
    #
    try:
        fpGM = open(gmFile, 'r')
    except:
        print 'Cannot open input file: ' + gmFile
        sys.exit(1)
    try:
        fpAssoc = open(assocFile, 'r')
    except:
        print 'Cannot open input file: ' + assocFile
        sys.exit(1)

    #
    # Open the output files.
    #
    try:
        fpGMBCP = open(gmBCPFile, 'w')
    except:
        print 'Cannot open output file: ' + gmBCPFile
        sys.exit(1)
    try:
        fpAssocBCP = open(assocBCPFile, 'w')
    except:
        print 'Cannot open output file: ' + assocBCPFile
        sys.exit(1)

    #
    # Open the report files.
    #
    try:
        fpInvMrkRpt = open(invMrkRptFile, 'a')
    except:
        print 'Cannot open report file: ' + invMrkRptFile
        sys.exit(1)
    try:
        fpSecMrkRpt = open(secMrkRptFile, 'a')
    except:
        print 'Cannot open report file: ' + secMrkRptFile
        sys.exit(1)
    try:
        fpMissGMRpt = open(missGMRptFile, 'a')
    except:
        print 'Cannot open report file: ' + missGMRptFile
        sys.exit(1)
    try:
        fpChrDiscrepRpt = open(chrDiscrepRptFile, 'a')
    except:
        print 'Cannot open report file: ' + chrDiscrepRptFile
        sys.exit(1)

    return


#
# Purpose: Close the files.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def closeFiles ():
    fpGM.close()
    fpAssoc.close()
    fpInvMrkRpt.close()
    fpSecMrkRpt.close()
    fpMissGMRpt.close()
    fpChrDiscrepRpt.close()

    return


#
# Purpose: Load the data from the input files into the temp tables.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def loadTempTables ():
    global assoc

    print 'Create a bcp file from the gene model input file'
    sys.stdout.flush()

    #
    # Read each record from the gene model input file, perform validation
    # checks and write them to a bcp file.
    #
    line = fpGM.readline()
    count = 1
    while line:
        tokens = re.split(TAB, line[:-1])
        gmID = tokens[0]
        chromosome = tokens[1]
        startCoordinate = tokens[2]
        endCoordinate = tokens[3]
        strand = tokens[4]
        description = tokens[5]

        if len(re.findall('[^0-9]',startCoordinate)) > 0:
            print 'Invalid start coordinate (line ' + str(count) + ')'
            fpGMBCP.close()
            closeFiles()
            sys.exit(1)

        if len(re.findall('[^0-9]',endCoordinate)) > 0:
            print 'Invalid end coordinate (line ' + str(count) + ')'
            fpGMBCP.close()
            closeFiles()
            sys.exit(1)

        if strand != '-' and strand != '+':
            print 'Invalid strand (line ' + str(count) + ')'
            fpGMBCP.close()
            closeFiles()
            sys.exit(1)

        fpGMBCP.write(gmID + TAB + chromosome + TAB +
                      startCoordinate + TAB + endCoordinate + TAB +
                      strand + TAB + description + NL)

        line = fpGM.readline()
        count += 1

    #
    # Close the bcp file.
    #
    fpGMBCP.close()

    print 'Create a bcp file from the association input file'
    sys.stdout.flush()

    #
    # Read each record from the association input file, perform validation
    # checks and write them to a bcp file.
    #
    line = fpAssoc.readline()
    count = 1
    while line:
        tokens = re.split(TAB, line[:-1])
        mgiID = tokens[0]
        gmID = tokens[1]

        if re.match('MGI:[0-9]+',mgiID) == None:
            print 'Invalid MGI ID (line ' + str(count) + ')'
            fpAssocBCP.close()
            closeFiles()
            sys.exit(1)

        fpAssocBCP.write(mgiID + TAB + gmID + NL)

        #
        # Maintain a dictionary of the MGI IDs that are in the association
        # input file. The value for each dictionary entry is a list of the
        # gene model IDs that are associated with the MGI ID key.
        #
        if assoc.has_key(mgiID):
            list = assoc[mgiID]
            list.append(gmID)
            assoc[mgiID] = list
        else:
            list = [ gmID ]
            assoc[mgiID] = list

        line = fpAssoc.readline()
        count += 1

    #
    # Close the bcp file.
    #
    fpAssocBCP.close()

    #
    # Load the temp tables with the input data.
    #
    print 'Load the gene model data into the temp table: ' + gmTempTable
    sys.stdout.flush()

    bcpCmd = 'cat %s | bcp tempdb..%s in %s -c -t"%s" -S%s -U%s' % (passwordFile, gmTempTable, gmBCPFile, TAB, db.get_sqlServer(), db.get_sqlUser())
    rc = os.system(bcpCmd)
    if rc <> 0:
        closeFiles()
        sys.exit(1)

    print 'Load the association data into the temp table: ' + assocTempTable
    sys.stdout.flush()

    bcpCmd = 'cat %s | bcp tempdb..%s in %s -c -t"%s" -S%s -U%s' % (passwordFile, assocTempTable, assocBCPFile, TAB, db.get_sqlServer(), db.get_sqlUser())
    rc = os.system(bcpCmd)
    if rc <> 0:
        closeFiles()
        sys.exit(1)

    return


#
# Purpose: Create the invalid marker report.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def createInvMarkerReport ():
    global assoc, errorCount

    print 'Create the invalid marker report'
    fpInvMrkRpt.write(string.center('Invalid Marker Report',110) + NL)
    fpInvMrkRpt.write(string.center(provider,110) + NL)
    fpInvMrkRpt.write(string.center('(' + timestamp + ')',110) + 2*NL)
    fpInvMrkRpt.write('%-12s  %-20s  %-20s  %-20s  %-30s%s' %
                     ('MGI ID','Gene Model ID','Associated Object',
                      'Marker Status','Reason',NL))
    fpInvMrkRpt.write(12*'-' + '  ' + 20*'-' + '  ' + 20*'-' + '  ' + \
                      20*'-' + '  ' + 30*'-' + NL)

    cmds = []

    #
    # Find any MGI IDs from the association file that:
    # 1) Do not exist in the database.
    # 2) Exist for a non-marker object.
    # 3) Exist for a marker, but the status is not "offical" or "interim".
    #
    cmds.append('select tmp.mgiID, ' + \
                       'tmp.gmID, ' + \
                       'null "name", ' + \
                       'null "status" ' + \
                'from tempdb..' + assocTempTable + ' tmp ' + \
                'where not exists (select 1 ' + \
                                  'from ACC_Accession a ' + \
                                  'where a.accID = tmp.mgiID) ' + \
                'union ' + \
                'select tmp.mgiID, ' + \
                       'tmp.gmID, ' + \
                       't.name, ' + \
                       'null "status" ' + \
                'from tempdb..' + assocTempTable + ' tmp, ' + \
                     'ACC_Accession a1, ' + \
                     'ACC_MGIType t ' + \
                'where a1.accID = tmp.mgiID and ' + \
                      'a1._LogicalDB_key = 1 and ' + \
                      'a1._MGIType_key != 2 and ' + \
                      'not exists (select 1 ' + \
                                  'from ACC_Accession a2 ' + \
                                  'where a2.accID = tmp.mgiID and ' + \
                                        'a2._LogicalDB_key = 1 and ' + \
                                        'a2._MGIType_key = 2) and ' + \
                      'a1._MGIType_key = t._MGIType_key ' + \
                'union ' + \
                'select tmp.mgiID, ' + \
                       'tmp.gmID, ' + \
                       't.name, ' + \
                       'ms.status ' + \
                'from tempdb..' + assocTempTable + ' tmp, ' + \
                     'ACC_Accession a, ' + \
                     'ACC_MGIType t, ' + \
                     'MRK_Marker m, ' + \
                     'MRK_Status ms ' + \
                'where a.accID = tmp.mgiID and ' + \
                      'a._LogicalDB_key = 1 and ' + \
                      'a._MGIType_key = 2 and ' + \
                      'a._MGIType_key = t._MGIType_key and ' + \
                      'a._Object_key = m._Marker_key and ' + \
                      'm._Marker_Status_key not in (1,3) and ' + \
                      'm._Marker_Status_key = ms._Marker_Status_key ' + \
                'order by tmp.mgiID, tmp.gmID')

    results = db.sql(cmds,'auto')

    #
    # Write the records to the report.
    #
    for r in results[0]:
        mgiID = r['mgiID']
        gmID = r['gmID']
        objectType = r['name']
        markerStatus = r['status']

        if objectType == None:
            objectType = ''
        if markerStatus == None:
            markerStatus = ''

        if objectType == '':
            reason = 'MGI ID does not exist'
        elif markerStatus == '':
            reason = 'MGI ID exists for non-marker'
        else:
            reason = 'Marker status is invalid'

        fpInvMrkRpt.write('%-12s  %-20s  %-20s  %-20s  %-30s%s' %
            (mgiID, gmID, objectType, markerStatus, reason, NL))

        #
        # If the MGI ID and gene model ID are found in the association
        # dictionary, remove the gene model ID from the list so the
        # association doesn't get written to the load-ready association file.
        #
        if liveRun == "1":
            if assoc.has_key(mgiID):
                list = assoc[mgiID]
                if list.count(gmID) > 0:
                    list.remove(gmID)
                assoc[mgiID] = list

    fpInvMrkRpt.write(NL + 'Number of Rows: ' + str(len(results[0])) + NL)

    errorCount += len(results[0])

    return


#
# Purpose: Create the secondary marker report.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def createSecMarkerReport ():
    global assoc, errorCount

    print 'Create the secondary marker report'
    fpSecMrkRpt.write(string.center('Secondary Marker Report',108) + NL)
    fpSecMrkRpt.write(string.center(provider,108) + NL)
    fpSecMrkRpt.write(string.center('(' + timestamp + ')',108) + 2*NL)
    fpSecMrkRpt.write('%-16s  %-20s  %-50s  %-16s%s' %
                     ('Secondary MGI ID','Gene Model ID',
                      'Marker Symbol','Primary MGI ID',NL))
    fpSecMrkRpt.write(16*'-' + '  ' + 20*'-' + '  ' + 50*'-' + '  ' + \
                      16*'-' + NL)

    cmds = []

    #
    # Find any MGI IDs from the association file that are secondary IDs
    # for a marker.
    #
    cmds.append('select tmp.mgiID, ' + \
                       'tmp.gmID, ' + \
                       'm.symbol, ' + \
                       'a2.accID ' + \
                'from tempdb..' + assocTempTable + ' tmp, ' + \
                     'ACC_Accession a1, ' + \
                     'ACC_Accession a2, ' + \
                     'MRK_Marker m ' + \
                'where tmp.mgiID = a1.accID and ' + \
                      'a1._MGIType_key = 2 and ' + \
                      'a1._LogicalDB_key = 1 and ' + \
                      'a1.preferred = 0 and ' + \
                      'a1._Object_key = a2._Object_key and ' + \
                      'a2._MGIType_key = 2 and ' + \
                      'a2._LogicalDB_key = 1 and ' + \
                      'a2.preferred = 1 and ' + \
                      'a2._Object_key = m._Marker_key ' + \
                'order by tmp.mgiID, tmp.gmID')

    results = db.sql(cmds,'auto')

    #
    # Write the records to the report.
    #
    for r in results[0]:
        mgiID = r['mgiID']
        gmID = r['gmID']

        fpSecMrkRpt.write('%-16s  %-20s  %-50s  %-16s%s' %
            (mgiID, gmID, r['symbol'], r['accID'], NL))

        #
        # If the MGI ID and gene model ID are found in the association
        # dictionary, remove the gene model ID from the list so the
        # association doesn't get written to the load-ready association file.
        #
        if liveRun == "1":
            if assoc.has_key(mgiID):
                list = assoc[mgiID]
                if list.count(gmID) > 0:
                    list.remove(gmID)
                assoc[mgiID] = list

    fpSecMrkRpt.write(NL + 'Number of Rows: ' + str(len(results[0])) + NL)

    errorCount += len(results[0])

    return


#
# Purpose: Create the missing gene model ID report.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def createMissingGMIDReport ():
    global assoc, errorCount

    print 'Create the missing gene model ID report'
    fpMissGMRpt.write(string.center('Missing Gene Model ID Report',80) + NL)
    fpMissGMRpt.write(string.center(provider,80) + NL)
    fpMissGMRpt.write(string.center('(' + timestamp + ')',80) + 2*NL)
    fpMissGMRpt.write('%-12s  %-20s%s' %
                     ('MGI ID','Gene Model ID',NL))
    fpMissGMRpt.write(12*'-' + '  ' + 20*'-' + NL)

    cmds = []

    #
    # Find any gene model IDs from the association file that are not in
    # the gene model file.
    #
    cmds.append('select ta.mgiID, ' + \
                       'ta.gmID ' + \
                'from tempdb..' + assocTempTable + ' ta ' + \
                'where not exists (select 1 ' + \
                                  'from tempdb..' + gmTempTable + ' tgm ' + \
                                  'where tgm.gmID = ta.gmID) ' + \
                'order by ta.gmID')

    results = db.sql(cmds,'auto')

    #
    # Write the records to the report.
    #
    for r in results[0]:
        mgiID = r['mgiID']
        gmID = r['gmID']

        fpMissGMRpt.write('%-12s  %-20s%s' % (mgiID, gmID, NL))

        #
        # If the MGI ID and gene model ID are found in the association
        # dictionary, remove the gene model ID from the list so the
        # association doesn't get written to the load-ready association file.
        #
        if liveRun == "1":
            if assoc.has_key(mgiID):
                list = assoc[mgiID]
                if list.count(gmID) > 0:
                    list.remove(gmID)
                assoc[mgiID] = list

    fpMissGMRpt.write(NL + 'Number of Rows: ' + str(len(results[0])) + NL)

    errorCount += len(results[0])

    return


#
# Purpose: Create the chromosome discrepancy report.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def createChrDiscrepReport ():
    global assoc, errorCount

    print 'Create the chromosome discrepancy report'
    fpChrDiscrepRpt.write(string.center('Chromosome Discrepancy Report',96) + NL)
    fpChrDiscrepRpt.write(string.center(provider,96) + NL)
    fpChrDiscrepRpt.write(string.center('(' + timestamp + ')',96) + 2*NL)
    fpChrDiscrepRpt.write('%-20s  %-3s  %-12s  %-50s  %-3s%s' %
                         ('Gene Model ID','Chr','MGI ID',
                          'Marker Symbol','Chr',NL))
    fpChrDiscrepRpt.write(20*'-' + '  ' + 3*'-' + '  ' + 12*'-' + '  ' +
                          50*'-' + '  ' + 3*'-' + NL)

    cmds = []

    #
    # Find any cases where the marker for the MGI ID in the association
    # file has a different chromosome than what is in the gene model file.
    #
    cmds.append('select tgm.gmID, ' + \
                       'tgm.chromosome "gmChr", ' + \
                       'ta.mgiID, ' + \
                       'm.symbol, ' + \
                       'm.chromosome "mrkChr" ' + \
                'from tempdb..' + gmTempTable + ' tgm, ' + \
                     'tempdb..' + assocTempTable + ' ta, ' + \
                     'ACC_Accession a, ' + \
                     'MRK_Marker m ' + \
                'where tgm.gmID = ta.gmID and ' + \
                      'ta.mgiID = a.accID and ' + \
                      'a._MGIType_key = 2 and ' + \
                      'a._LogicalDB_key = 1 and ' + \
                      'a.preferred = 1 and ' + \
                      'a._Object_key = m._Marker_key and ' + \
                      'm.chromosome != tgm.chromosome ' + \
                'order by tgm.gmID')

    results = db.sql(cmds,'auto')

    #
    # Write the records to the report.
    #
    for r in results[0]:
        mgiID = r['mgiID']
        gmID = r['gmID']

        fpChrDiscrepRpt.write('%-20s  %-3s  %-12s  %-50s  %-3s%s' %
            (gmID, r['gmChr'], mgiID, r['symbol'], r['mrkChr'], NL))

        #
        # If the MGI ID and gene model ID are found in the association
        # dictionary, remove the gene model ID from the list so the
        # association doesn't get written to the load-ready association file.
        #
        if liveRun == "1":
            if assoc.has_key(mgiID):
                list = assoc[mgiID]
                if list.count(gmID) > 0:
                    list.remove(gmID)
                assoc[mgiID] = list

    fpChrDiscrepRpt.write(NL + 'Number of Rows: ' + str(len(results[0])) + NL)

    errorCount += len(results[0])

    return


#
# Purpose: Create the load-ready association file from the dictionary of
#          associations that did not have any discrepancies.
# Returns: Nothing
# Assumes: Nothing
# Effects: Nothing
# Throws: Nothing
#
def createAssocLoadFile ():
    try:
        fpAssocLoad = open(assocLoadFile, 'w')
    except:
        print 'Cannot open output file: ' + assocLoadFile
        sys.exit(1)

    fpAssocLoad.write('MGI' + TAB + logicalDB + NL)

    mgiIDList = assoc.keys()
    mgiIDList.sort()

    for mgiID in mgiIDList:
        gmIDList = assoc[mgiID]
        for gmID in gmIDList:
            fpAssocLoad.write(mgiID + TAB + gmID + NL)

    fpAssocLoad.close()


#
# Main
#
init()
openFiles()
loadTempTables()
createInvMarkerReport()
createSecMarkerReport()
createMissingGMIDReport()
createChrDiscrepReport()
closeFiles()

if liveRun == "1":
    createAssocLoadFile()

if errorCount > 0:
    sys.exit(2)
else:
    sys.exit(0)
