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

### Constants ###

# Biotype vocab keys
ENSEMBL_VOCAB_KEY = 103
NCBI_VOCAB_KEY = 104
VEGA_VOCAB_KEY = 105
# MCV vocab key
MCV_VOCAB_KEY = 79

createdByKey = 1001
cdate = mgi_utils.date('%m/%d/%Y')	# current date

# sanity check error messages
INVALID_VOCAB_ERROR = "Invalid BioType Vocab (row %d): %s"
INVALID_BIOTYPE_TERM_ERROR = "Invalid BioType Term (row %d): %s, for vocab %s"
INVALID_MARKER_TYPE_ERROR = "Invalid Marker Type Term (row %d): %s"
INVALID_MCV_TERM_ERROR = "Invalid MCV/Feature Type Term (row %d): %s"


### Globals ###
DEBUG = 0		# set DEBUG to false unless preview mode is selected
bcpon = 1		# can the bcp files be bcp-ed into the database?  default is yes (1).

inputFile = ''		# file descriptor
outputFile = ''		# file descriptor
diagFile = ''		# file descriptor
errorFile = ''		# file descriptor

biotypeKey = 1		# _biotypemapping_key always starts at 1
biotypeVocabKey = 0
biotypeTerm = None
biotypeTermKey = 0
mcvTerms = []
mcvTermKeys = []
markerType = None
markerTypeKey = 0

#
# from configuration file
#
# BIOTYPEMODE
mode = None
# BIOTYPETABLE
biotypeTable = None
# BCP_CMD
bcpCommand = None
# OUTPUTDIR
outputFileDir = None
# BIOTYPEINPUT_FILE_DEFAULT
inputFileName = None
# name of BCP file
bcpFileName = None
# full path of bcp file
outputFileName = None
# BIOTYPELOG_DIAG
diagFileName = None
# BIOTYPELOG_ERROR
errorFileName = None


def initConfig():
    """
    Initialize any required environment variables
	and input/output file names
    """
    global mode
    global biotypeTable
    global bcpCommand
    global outputFileDir
    global inputFileName
    global bcpFileName
    global outputFileName
    global diagFileName
    global errorFileName
    mode = os.environ['BIOTYPEMODE']
    biotypeTable = os.environ['BIOTYPETABLE']
    bcpCommand = os.environ['BCP_CMD']
    outputFileDir = os.environ['OUTPUTDIR']
    inputFileName = os.environ['BIOTYPEINPUT_FILE_DEFAULT']
    bcpFileName = biotypeTable + '.bcp'
    outputFileName = os.environ['OUTPUTDIR'] + '/' + bcpFileName
    diagFileName = os.environ['BIOTYPELOG_DIAG']
    errorFileName = os.environ['BIOTYPELOG_ERROR']


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
    #   List [] of error messages if sanity check fails
    #   Empty list [] if all sanity checks pass
    #
    '''

    global biotypeVocabKey
    global biotypeTermKey
    global mcvTermKeys
    global markerTypeKey

    errors = []
    mcvTermKeys = []

    #
    # BioType Vocabularies
    #
    biotypeVocabKey = 0

    if biotypeVocab == 'Ensembl':
	biotypeVocabKey = ENSEMBL_VOCAB_KEY
    elif biotypeVocab == 'NCBI':
	biotypeVocabKey = NCBI_VOCAB_KEY
    elif biotypeVocab == 'VEGA':
	biotypeVocabKey = VEGA_VOCAB_KEY
    else:
        errors.append( INVALID_VOCAB_ERROR % (lineNum, biotypeVocab) )

    # Lookup the biotype _term_key for this vocab/term
    if biotypeVocabKey:
	biotypeTermKey = loadlib.verifyTerm('', biotypeVocabKey, biotypeTerm, lineNum, errorFile)
	if biotypeTermKey == 0:
	    errors.append( INVALID_BIOTYPE_TERM_ERROR % (lineNum, biotypeTerm, biotypeVocab) )

    # lookup the _marker_type_key
    markerTypeKey = loadlib.verifyMarkerType(markerType, lineNum, errorFile)
    if markerTypeKey == 0:
        errors.append( INVALID_MARKER_TYPE_ERROR % (lineNum, markerType) )

    # 
    # mcv/feature types
    #
    tokens = mcvTerms.split('|')
    for r in tokens:
	t = loadlib.verifyTerm('', MCV_VOCAB_KEY, r, lineNum, errorFile)
	if t == 0:
            errors.append( INVALID_MCV_TERM_ERROR % (lineNum, r) )
    	else:
            mcvTermKeys.append(t)

    return errors

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

	errors = sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
        if errors :
	    errorFile.write('\n'.join(errors) + '\n')
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

    diagFile.write('truncating %s' % biotypeTable)
    db.sql('truncate table %s' % biotypeTable, None)

    diagFile.write('BCP into %s' % biotypeTable)
    db.bcp(outputFileName, biotypeTable, delimiter='|')


def main():

    print 'initConfig()'
    initConfig()

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


if __name__ == '__main__':
	db.useOneConnection(1)
	db.sql('start transaction', None)

	# do main processing
	main()

	db.commit()

