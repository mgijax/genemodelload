'''
#
# Purpose:
#
#	To load new gene records into Nomen structures: MRK_BiotypeMapping
#
# Input:
#
#	A tab-delimited file in the format:
#		field 1: Provider (Ensembl, NCBI, MGP) (_biotypevocab_key)
#		field 2: biotype term (_biotypeterm_key)
#		field 3: pipe-delimited list of feature types (_MCVTerm_key)
#		field 4: primary biotype (not used)
#		field 5: marker type (see MRK_Types)
#	    field 6: use feature type children (yes/no)
#
#	4 provider vocabularies exist:
#		_vocab_key : 103 (BioType Ensembl)
#		_vocab_key : 104 (BioType NCBI)
#		_vocab_key : 136 (BioType Mouse Genome Project)
#		_vocab_key : 175 (BioType VISTA)
#		_vocab_key : 176 (BioType Ensembl Regulatory Feature)
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

### Constants ###

# Biotype vocab keys
ENSEMBL_VOCAB_KEY = 103
NCBI_VOCAB_KEY = 104
MGP_VOCAB_KEY = 136
ENSEMBLREG_VOCAB_KEY = 176
VISTAREG_VOCAB_KEY = 175

# MCV vocab key
MCV_VOCAB_KEY = 79

createdByKey = 1001
cdate = mgi_utils.date('%m/%d/%Y')	# current date

# sanity check error messages
INVALID_VOCAB_ERROR = "Invalid BioType Vocab (row %d): %s"
INVALID_BIOTYPE_TERM_ERROR = "Invalid BioType Term (row %d): %s, for vocab %s"
INVALID_MARKER_TYPE_ERROR = "Invalid Marker Type Term (row %d): %s"
INVALID_MCV_TERM_ERROR = "Invalid MCV/Feature Type Term (row %d): %s"
INVALID_PRIMARY_FEATURE_ERROR = "Invalid Primary Feature Type Term (row %d): %s"

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
useMCVchildren = None

#
# from configuration file
#
# BIOTYPEMODE
mode = None

# BIOTYPETABLE
biotypeTable = None

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
    '''
    #
    # Initialize any required environment variables
    #   and input/output file names
    #
    '''

    global mode
    global biotypeTable
    global outputFileDir
    global inputFileName
    global bcpFileName
    global outputFileName
    global diagFileName
    global errorFileName
    global bcpCommand

    mode = os.environ['BIOTYPEMODE']
    biotypeTable = os.environ['BIOTYPETABLE']
    outputFileDir = os.environ['OUTPUTDIR']
    inputFileName = os.environ['BIOTYPEINPUT_FILE_DEFAULT']
    bcpFileName = biotypeTable + '.bcp'
    outputFileName = os.environ['OUTPUTDIR'] + '/' + bcpFileName
    diagFileName = os.environ['BIOTYPELOG_DIAG']
    errorFileName = os.environ['BIOTYPELOG_ERROR']
    bcpCommand = os.environ['BCP_CMD']

def exit(status, message = None):
    '''
    # requires: status, the numeric exit status (integer)
    #           message (str.
    #
    # effects:
    # Print message to stderr and exits
    #
    # returns:
    #
    '''

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

def sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, primaryMCVTerm, markerType, lineNum):
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
    global primaryMCVTermKey

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
    elif biotypeVocab == 'MGP':
        biotypeVocabKey = MGP_VOCAB_KEY
    elif biotypeVocab == 'EnsemblR':
        biotypeVocabKey = ENSEMBLREG_VOCAB_KEY
    elif biotypeVocab == 'VISTA':
        biotypeVocabKey = VISTAREG_VOCAB_KEY
    else:
        errors.append(INVALID_VOCAB_ERROR % (lineNum, biotypeVocab) )

    # Lookup the biotype _term_key for this vocab/term
    if biotypeVocabKey:
        biotypeTermKey = loadlib.verifyTerm('', biotypeVocabKey, biotypeTerm, lineNum, errorFile)
        if biotypeTermKey == 0:
            errors.append(INVALID_BIOTYPE_TERM_ERROR % (lineNum, biotypeTerm, biotypeVocab) )

    # lookup the _marker_type_key
    markerTypeKey = loadlib.verifyMarkerType(markerType, lineNum, errorFile)
    if markerTypeKey == 0:
        errors.append(INVALID_MARKER_TYPE_ERROR % (lineNum, markerType) )

    # 
    # mcv/feature types
    #
    tokens = mcvTerms.split('|')
    for r in tokens:
        t = loadlib.verifyTerm('', MCV_VOCAB_KEY, r, lineNum, errorFile)
        if t == 0:
            errors.append(INVALID_MCV_TERM_ERROR % (lineNum, r) )
        else:
            mcvTermKeys.append(t)

    # lookup the primary feature type
    primaryMCVTermKey = loadlib.verifyTerm('', MCV_VOCAB_KEY, primaryMCVTerm, lineNum, errorFile)
    if primaryMCVTermKey == 0:
        errors.append(INVALID_MARKER_TYPE_ERROR % (lineNum, primaryMCVTerm) )

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
    global useMCVchildren
    global primaryMCVTerm, primaryMCVTermKey

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
            primaryMCVTerm = tokens[3]
            markerType = tokens[4]
            useMCVchildren = tokens[5]
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

        errors = sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, primaryMCVTerm, markerType, lineNum)
        if errors :
            errorFile.write('\n'.join(errors) + '\n')
            errorFile.write(str(tokens) + '\n\n')
            bcpon = 0
            continue

        #
        # sanity checks passed...
        #

        if useMCVchildren == 'yes':
                useMCVchildren = '1'
        else:
                useMCVchildren = '0'

        for mcvTermKey in mcvTermKeys:
                outputFile.write('%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s\n' \
                % (biotypeKey, biotypeVocabKey, biotypeTermKey, mcvTermKey, primaryMCVTermKey, markerTypeKey, useMCVchildren,
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

def main():
    '''
    #
    # main processing
    #
    '''

    print('initConfig()')
    initConfig()

    print('verifyMode()')
    verifyMode()

    print('init()')
    init()

    print('processFile()')
    processFile()

    if not DEBUG and bcpon:
        print('sanity check PASSED : loading data')
        bcpFiles()
        exit(0)
    else:
        exit(1)

if __name__ == '__main__':

        #db.setTrace()
        db.sql('start transaction', None)

        # do main processing
        main()
