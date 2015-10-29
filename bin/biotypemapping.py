#!/usr/local/bin/python

'''
#
# Purpose:
#
#	To load new gene records into Nomen structures: MRK_BiotypeMapping
#
# Input:
#
#	A tab-delimited file in the format:
#		field 1: Provider (Ensembl, NCBI, VEGA) (_biotypevocab_key)
#		field 2: biotype term (_biotypeterm_key)
#		field 3: pipe-delimited list of feature types (_MCVTerm_key)
#		field 4: primary biotype (not used)
#		field 5: marker type (see MRK_Types)
#
#	3 provider vocabularies exist:
#		_vocab_key : 103 (Biotype Ensembl)
#		_vocab_key : 104 (Biotype NCBI)
#		_vocab_key : 105 (Biotype VEGA)
#
# Parameters:
#
#	processing modes:
#		load - run sanity checks & delete/reload the data into MRK_BiotypeMapping table
#		preview - run sanity checks only
#
# Sanity Checks: see sanityCheck()
#
#        1)  Invalid Line (missing column(s))
#        2)  Invalid Biotype Term
#        3)  Invalid MCV (Feature) Term
#        4)  Invalid Marker Type
#
# Output:
#
#       1 BCP files:
#	Diagnostics file of all input parameters and SQL commands
#	Error file
#
# Processing:
#	See biotypemapload wiki:
#	http://prodwww.informatics.jax.org/software/wiki/index.php/Biotypemapload
#
# History:
#
# lec   10/21/2015
#       - TR12027/12116/biotypemapping
#
'''

import sys
import os
import db
import mgi_utils
import loadlib

#db.setTrace()

#globals

#
# from configuration file
#
mode = os.environ['BIOTYPEMODE']
biotypeTable = os.environ['BIOTYPETABLE']
bcpCommand = os.environ['BCP_CMD']
outputFileDir = os.environ['OUTPUTDIR']
inputFileName = os.environ['BIOTYPEINPUT_FILE_DEFAULT']
bcpFileName = biotypeTable + '.bcp'
outputFileName = os.environ['OUTPUTDIR'] + '/' + bcpFileName
diagFileName = os.environ['BIOTYPELOG_DIAG']
errorFileName = os.environ['BIOTYPELOG_ERROR']

DEBUG = 0		# set DEBUG to false unless preview mode is selected
bcpon = 1		# can the bcp files be bcp-ed into the database?  default is yes (1).

inputFile = ''		# file descriptor
outputFile = ''		# file descriptor
diagFile = ''		# file descriptor
errorFile = ''		# file descriptor

biotypeKey = 1		# _biotypemapping_key always starts at 1
biotypeTerm = None
biotypeTermKey = 0
mcvTerms = []
mcvTermKeys = []
markerType = None
markerTypeKey = 0
mcvVocabKey = 79

createdByKey = 1001
cdate = mgi_utils.date('%m/%d/%Y')	# current date

def exit(status, message = None):
    '''
    # requires: status, the numeric exit status (integer)
    #           message (string)
    #
    # effects:
    # Print message to stderr and exits
    #
    # returns:
    #
    '''

    db.commit()
    db.useOneConnection()

    if message is not None:
	sys.stderr.write('\n' + str(message) + '\n')

    try:
	inputFile.close()
	diagFile.flush()
	errorFile.flush()
	diagFile.write('\n\nEnd Date/Time: %s\n' % (mgi_utils.date()))
        errorFile.write('\nEnd file\n')
	diagFile.close()
	errorFile.close()
    except:
	pass

    sys.exit(status)
 
def init():
    '''
    # requires: 
    #
    # effects: 
    # 1. Processes command line options
    # 2. Initializes local DBMS parameters
    # 3. Initializes global file descriptors/file names
    #
    # returns:
    #
    '''

    global inputFile, outputFile, diagFile, errorFile
    global inputFileName, errorFileName, diagFileName, outputFileName

    db.useOneConnection(1)

    try:
	inputFile = open(inputFileName, 'r')
    except:
	exit(1, 'Could not open file %s\n' % inputFileName)
	    
    try:
	diagFile = open(diagFileName, 'w+')
    except:
	exit(1, 'Could not open file %s\n' % diagFileName)
	    
    try:
	errorFile = open(errorFileName, 'w')
    except:
	exit(1, 'Could not open file %s\n' % errorFileName)
	    
    try:
	outputFile = open(outputFileName, 'w')
    except:
	exit(1, 'Could not open file %s\n' % outputFileName)
	    
    # Log all SQL 
    db.set_sqlLogFunction(db.sqlLogAll)

    # Set Log File Descriptor
    db.set_commandLogFile(diagFileName)

    # Set Log File Descriptor
    diagFile.write('Start Date/Time: %s\n' % (mgi_utils.date()))
    diagFile.write('Server: %s\n' % (db.get_sqlServer()))
    diagFile.write('Database: %s\n' % (db.get_sqlDatabase()))
    diagFile.write('Input File: %s\n' % (inputFileName))
    errorFile.write('\nStart file: %s\n\n' % (mgi_utils.date()))

def verifyMode():
    '''
    # requires:
    #
    # effects:
    #	Verifies the processing mode is valid.  If it is not valid,
    #	the program is aborted.
    #	Sets globals based on processing mode.
    #	Deletes data based on processing mode.
    #
    # returns:
    #	nothing
    #
    '''

    global DEBUG, bcpon

    if mode == 'preview':
	DEBUG = 1
	bcpon = 0
    elif mode not in ['load']:
	exit(1, 'Invalid Processing Mode:  %s\n' % (mode))

    # the shell wrapper will truncate the table
    #else:
    	#db.sql('truncate table mgd.%s' % (biotypeTable), None)
	#db.commit()

def sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum):
    '''
    #
    # requires:
    #
    # effects:
    #
    # returns:
    #	0 if sanity check passes
    #	1 if sanity check fails
    #
    '''

    global biotypeVocabKey
    global biotypeTermKey
    global mcvTermKeys
    global markerTypeKey

    error = 0
    mcvTermKeys = []

    #
    # BioType Vocabularies
    #

    if biotypeVocab == 'Ensembl':
	biotypeVocabKey = 103
    elif biotypeVocab == 'NCBI':
	biotypeVocabKey = 104
    elif biotypeVocab == 'VEGA':
	biotypeVocabKey = 105
    else:
	errorFile.write('Invalid BioType Term (row %d): %s\n' % (lineNum, biotypeVocab))
	error = 1
    	return (error)

    biotypeTermKey = loadlib.verifyTerm('', biotypeVocabKey, biotypeTerm, lineNum, errorFile)
    markerTypeKey = loadlib.verifyMarkerType(markerType, lineNum, errorFile)

    if biotypeTermKey == 0 or \
       markerTypeKey == 0:

        # set error flag to true
	error = 1

    # 
    # mcv/feature types
    #
    tokens = mcvTerms.split('|')
    for r in tokens:
	t = loadlib.verifyTerm('', mcvVocabKey, r, lineNum, errorFile)
	if t == 0:
	    errorFile.write('Invalid MCV/Feature Type Term (row %d): %s\n' % (lineNum, r))
	    error = 1
    	else:
            mcvTermKeys.append(t)

    return (error)

def processFile():
    '''
    # requires:
    #
    # effects:
    #	Reads input file
    #	Verifies and Processes each line in the input file
    #
    # returns:
    #	nothing
    #
    '''

    global bcpon
    global biotypeKey
    global biotypeVocab, biotypeVocabKey
    global biotypeTerm, biotypeTermKey
    global mcvTerms, mcvTermKeys
    global markerType, markerTypeKey

    # For each line in the input file

    lineNum = 0

    for line in inputFile.readlines():

	lineNum = lineNum + 1

	# Split the line into tokens
	tokens = line[:-1].split('\t')

	try:
	    biotypeVocab = tokens[0]
	    biotypeTerm = tokens[1]
	    mcvTerms = tokens[2]
	    markerType = tokens[4]
	except:
	    errorFile.write('Invalid Line (missing column(s)) (row %d): %s\n' % (lineNum, line))
	    continue

	#
	# skip header
	#
	if biotypeVocab == "Source":
		continue

	#
	# sanity checks
	#

        if sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum) == 1:
	    errorFile.write(str(tokens) + '\n\n')
	    bcpon = 0
	    continue

	#
	# sanity checks passed...
	#

	for mcvTermKey in mcvTermKeys:
		outputFile.write('%d|%d|%d|%d|%d|%s|%s|%s|%s\n' \
	    	% (biotypeKey, biotypeVocabKey, biotypeTermKey, mcvTermKey, markerTypeKey,
			createdByKey, createdByKey, cdate, cdate))
		biotypeKey = biotypeKey + 1

    # end of "for line in inputFile.readlines():"

    outputFile.close()
    db.commit()

def bcpFiles():
    '''
    # requires:
    #
    # effects:
    #	BCPs the data into the database
    #
    # returns:
    #	nothing
    #
    '''

    bcp1 = '''%s %s %s %s '|' '\\n' mgd''' % (bcpCommand, biotypeTable, outputFileDir, bcpFileName)
    diagFile.write('%s\n' % bcp1)
    os.system(bcp1)

#
# Main
#

print 'verifyMode()'
verifyMode()

print 'init()'
init()

print 'processFile()'
processFile()

if not DEBUG and bcpon:
    print 'sanity check PASSED : loading data'
    bcpFiles()
    exit(0)
else:
    exit(1)
