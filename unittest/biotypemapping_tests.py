#!/usr/local/bin/python
#
# Unit tests for the genemodelload biotypemapping module
# 
#

import sys,os.path
# adjust the path for running the tests locally, so that it can find the modules
sys.path.insert(0,os.path.join(os.path.dirname(__file__), '../bin'))
import unittest

import biotypemapping

class BiotypeMappingSanityCheckTest(unittest.TestCase):
	"""
	Test the sanityCheck() processing of biotypemapping input file
	"""

	def setUp (self):
		"""
		Set up any global variables we want initialized
			or ignored for these tests
		"""

		# send error log to dev/null
		biotypemapping.errorFile = open(os.devnull,"w")

		# vocab keys
		self.ensemblKey = biotypemapping.ENSEMBL_VOCAB_KEY 
		self.ncbiKey = biotypemapping.NCBI_VOCAB_KEY
		self.vegaKey = biotypemapping.VEGA_VOCAB_KEY
		self.mcvVocabKey = biotypemapping.MCV_VOCAB_KEY

		# Mock database objects for test term lookups
		self.biotypeTerm = 'testBiotype'
		self.markerType = 'testMarkerType'
		self.mcvTerm = 'testMCV'
		self.mcvTerm2 = 'testMCV2'

		# mock biotypeTerm
		# once for each vocab
		self.saveMockTerm(self.ensemblKey, self.biotypeTerm, 1)
		self.saveMockTerm(self.ncbiKey, self.biotypeTerm, 1)
		self.saveMockTerm(self.vegaKey, self.biotypeTerm, 1)
		# mock markerTypeKey
		self.saveMockMarkerType(self.markerType, 1)
		# mock mcvTerm
		self.saveMockTerm(self.mcvVocabKey, self.mcvTerm, 11)
		self.saveMockTerm(self.mcvVocabKey, self.mcvTerm2, 12)


	def tearDown(self):
		"""
		Need to reset the loadlib.termDict
		"""
		biotypemapping.loadlib.termDict = {}


	def saveMockTerm(self, vocabKey, termID, termKey):
		"""
		Save a mock database term to the loadlib
			for mock database validations
		"""
		biotypemapping.loadlib.termDict[(vocabKey, termID)] = termKey

	def saveMockMarkerType(self, markerType, markerTypeKey):
		"""
		Save a mock database _marker_type_key to the loadlib
			for mock database validations
		"""
		biotypemapping.loadlib.markerTypeDict[markerType] = markerTypeKey


	def test_empty_row(self):
		"""
		Should trigger vocab, markerType, and mcvTerm errors
		"""
		biotypeVocab = ''
		biotypeTerm = ''
		mcvTerms = ''
		markerType = ''
		lineNum = 0
		expected = [
			biotypemapping.INVALID_VOCAB_ERROR % (lineNum, biotypeVocab),
			biotypemapping.INVALID_MARKER_TYPE_ERROR % (lineNum, markerType),
			biotypemapping.INVALID_MCV_TERM_ERROR % (lineNum, ''),
		]
		errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
		self.assertEquals(expected, errors) 


	### Test biotypeVocab ###
	def test_ensembl_vocab(self):
                biotypeVocab = 'Ensembl'
                biotypeTerm = self.biotypeTerm
                mcvTerms = self.mcvTerm
                markerType = self.markerType
                lineNum = 1
		
                expected = []
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)

	def test_ncbi_vocab(self):
                biotypeVocab = 'NCBI'
                biotypeTerm = self.biotypeTerm
                mcvTerms = self.mcvTerm
                markerType = self.markerType
                lineNum = 1
		
                expected = []
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)

	def test_vega_vocab(self):
                biotypeVocab = 'VEGA'
                biotypeTerm = self.biotypeTerm
                mcvTerms = self.mcvTerm
                markerType = self.markerType
                lineNum = 1
		
                expected = []
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)

	def test_invalid_vocab(self):
                biotypeVocab = 'INVALID VOCAB'
                biotypeTerm = self.biotypeTerm
                mcvTerms = self.mcvTerm
                markerType = self.markerType
                lineNum = 1
		
                expected = [biotypemapping.INVALID_VOCAB_ERROR % (lineNum, biotypeVocab) ]
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)


	### Test Biotype Term ###
	def test_biotype_term_invalid(self):
                biotypeVocab = 'Ensembl'
                biotypeTerm = 'does not exist'
                mcvTerms = self.mcvTerm
                markerType = self.markerType
                lineNum = 1

                expected = [biotypemapping.INVALID_BIOTYPE_TERM_ERROR % (lineNum, biotypeTerm, biotypeVocab) ]
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)

	def test_biotype_term_wrong_vocab(self):
		"""
		Using the biotype term from a different provider
			should trigger an error
		"""
                biotypeVocab = 'Ensembl'
                biotypeTerm = 'vegaBiotype'
                mcvTerms = self.mcvTerm
                markerType = self.markerType
                lineNum = 1

		# save a special vega only biotype term
		self.saveMockTerm(self.vegaKey, 'vegaBiotype', 99)
		
                expected = [biotypemapping.INVALID_BIOTYPE_TERM_ERROR % (lineNum, biotypeTerm, biotypeVocab) ]
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)


	### Test Marker Type ###
	def test_marker_type_invalid(self):
                biotypeVocab = 'Ensembl'
                biotypeTerm = self.biotypeTerm
                mcvTerms = self.mcvTerm
                markerType = 'does not exist'
                lineNum = 1

                expected = [biotypemapping.INVALID_MARKER_TYPE_ERROR % (lineNum, markerType) ]
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)


	### Test MCV / Feature Type ###
	def test_feature_type_invalid(self):
                biotypeVocab = 'Ensembl'
                biotypeTerm = self.biotypeTerm
                mcvTerms = 'does not exist'
                markerType = self.markerType
                lineNum = 1

                expected = [biotypemapping.INVALID_MCV_TERM_ERROR % (lineNum, 'does not exist') ]
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)

	def test_multiple_feature_types(self):
                biotypeVocab = 'Ensembl'
                biotypeTerm = self.biotypeTerm
                mcvTerms = '%s|%s' % (self.mcvTerm, self.mcvTerm2)
                markerType = self.markerType
                lineNum = 1

		expected = []
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)


	def test_multiple_invalid_feature_types(self):
                biotypeVocab = 'Ensembl'
                biotypeTerm = self.biotypeTerm
                mcvTerms = 'fakeMCV1|fakeMCV2|fakeMCV3'
                markerType = self.markerType
                lineNum = 1

		expected = [
			biotypemapping.INVALID_MCV_TERM_ERROR % (lineNum, 'fakeMCV1'),
			biotypemapping.INVALID_MCV_TERM_ERROR % (lineNum, 'fakeMCV2'),
			biotypemapping.INVALID_MCV_TERM_ERROR % (lineNum, 'fakeMCV3'),
		]
                errors = biotypemapping.sanityCheck(biotypeVocab, biotypeTerm, mcvTerms, markerType, lineNum)
                self.assertEquals(expected, errors)

if __name__ == '__main__':
        unittest.main()
