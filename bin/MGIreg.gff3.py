
'''
#Report:
#       Tab-delimited file of Ensembl and VISTA regulatory region coordinates
#       (Cre and More Project (CREAM))
#
#   1. chromosome: e.g. '19' 
#   2. source of feature: mrk_location_cache.provider.  'Ensembl Reg' or 'VISTA'
#   3. gene feature: MGI Feature Type e.g. CTCF binding site or enhancer 
#   4. start coordinate
#   5. end coordinate
#   6. score: '.'
#   7. strand: '.'
#   8. frame: '.'
#   9. feature attributes: Creator; Sequence_tag_ID; GenBank_ID; DBxref; Type
#	- where: 
#         'ID' an internal ID
#   	  'Name' Marker Symbol
#	  'description' Marker name
#         'curie' Marker MGI ID
#	  'Dbxref'  ENSEMBL or VISTA IDs
#	  'bound_start ENSEMBL only from the ensembl.gff
#         'bound_end ENSEMBL only from the ensembl regulatory gff file
#             VISTA: no bounds
#         'mgi_type MGI feature type
#         'so_term_name SO term
#
# Usage:
#     ${PYTHON} MGIreg.gff3.py 
#
# History:
#
# 5/18/2022 sc - created
#
'''
 
import sys
import os
import string
import mgi_utils
import reportlib
import db
import time

db.setTrace()

CRT = reportlib.CRT
TAB = reportlib.TAB
date = mgi_utils.date('%m/%d/%Y %H:%M:%S') #("%Y-%m-%d")

mAssembly = os.getenv('MOUSE_ASSEMBLY')

# ENSEMBL GFF Configuration

# zipped version of ensembl gff - filename from source
sourceEnsemblGFF = os.getenv('ENSEMBL_GFF')

# local unzipped sourceEnsemblGFF file from which to parse bounds
ensemblGFF = os.getenv('ENSEMBL_GFF_DEFAULT')

# just the file name w/o extension
baseEnsemblGFF = os.path.splitext(os.path.basename(sourceEnsemblGFF))[0]

# URL from which we get sourceEnsembGFF
ensemblGFFUrl = os.getenv('ENSEMBL_GFF_URL')

# creation time of sourceEnsemblGFF
ensemblGFFTimeStamp = time.ctime(os.path.getmtime(sourceEnsemblGFF))

# VISTA GFF Configuration

# where to write the gff file and its name
outputDir = os.getenv('OUTPUTDIR')
fileName = 'MGIreg.gff3'

# mapping of MCV ID to SO ID and Term
mcvIdToSODict = {}

# mapping of Ensembl ID to bound_start and bound_end from ensembl regulatory 
# gff file
boundsDict = {}

def init():
    global fp, finalResults
    
    db.useOneConnection(1)
    fp = open('%s/%s' % (outputDir, fileName), 'w')

    #
    # create SO ID to SO Term lookup
    #

    # get MCV terms with their accids
    db.sql('''select a.accid as mcvID, t._term_key as mcvTermKey, 
        t.term as mcvTerm, t.note as mcvNote
        into temporary table mcv
        from voc_term t, acc_accession a
        where a._logicaldb_key = 146
        and a._mgitype_key = 13
        and a._object_key = t._term_key''', None)

    # pull in the SO ID - it has same _term_key, but different ldb
    db.sql('''select a.accid as soID, m.*
        into temporary table mcv_so
        from acc_accession a, mcv m
        where m.mcvTermKey = a._object_key
        and a._mgitype_key = 13 
        and a._logicaldb_key = 145''', None)

    # now get the SO term for the SO ID = this requires joining to the accession table AND to the term table for the SO vocab
    # we are not using everything in the select clause, but I left it be for cut/paste debugging if needed later - this query
    # was a bear to put together.
    results = db.sql('''select t.term as soTerm, t.note as soNote, ms.soID, 
        t._term_key as 
            soTermKey,  ms.mcvTerm, ms.mcvNote, ms.mcvID, ms.mcvTermKey
        from voc_term t, acc_accession a, mcv_so ms
        where ms.soID = a.accid
        and a._mgitype_key = 13
        and a._logicaldb_key = 145
        and a._object_key = t._term_key
        and t._vocab_key = 138''', 'auto')

    # not sure if we need the SO ID but getting it now just in case
    for r in results:
        soList = [r['soID'], r['soTerm']]
        mcvIdToSODict[r['mcvID']] = soList

    db.sql('''select a1.accid as seqID, a1._logicaldb_key, a2.accid as markerID,
            c.provider, c.genomicchromosome, c. startcoordinate, 
            c.endcoordinate, c.strand, m.symbol, m.name, t.name as markerType, 
            mcv.term as mcvTerm
        into temporary table ev
        from mrk_location_cache c, acc_accession a1, acc_accession a2, 
            mrk_marker m, mrk_mcv_cache mcv, mrk_types t
        where a1._logicaldb_key in (222, 223)
        and a1._mgitype_key = 2
        and a1._object_key = c._marker_key
        and a1._object_key = a2._object_key
        and a2._mgitype_key = 2
        and a2._logicaldb_key = 1
        and c._marker_key = m._marker_key
        and m._marker_type_key = t._marker_type_key
        and c._marker_key = mcv._marker_key
        and mcv.qualifier = 'D' ''', None)

    db.sql('''create index idx1 on ev(mcvTerm)''', None)

    finalResults = db.sql('''select ev.*, a.accid as mcvID 
        from ev, voc_term t, acc_accession a
        where ev.mcvTerm = t.term
        and t._term_key = a._object_key
        and a._mgitype_key = 13
        and a._logicaldb_key = 146
        order by ev.provider, ev.genomicchromosome, ev.startcoordinate ''', 'auto')

    # Create lookup of bounds by ensembl id

    fpE = open(ensemblGFF, 'r', encoding='latin-1')
    for line in fpE:
        col9 = str.split(line, TAB)[8]
        fields = str.split(col9, ';')
        ens_id = '' 
        bound_start = ''
        bound_end = ''
        for f in fields:
            if f.find('ID') == 0:
                # Example: ID=TF_binding_site:ENSMUSR00000612461
                ens_id =  f.split('=')[1].split(':')[1]
            elif f.find('bound_start') == 0:
                    bound_start = f.split('=')[1]
            elif f.find('bound_end') == 0:
                    bound_end = f.split('=')[1]

        if ens_id == '' or bound_start == '' or bound_end == '':
            print('Missing: ens_id: %s bound_start: %s bound_end: %s' % (ens_id, bound_start, bound_end))
        else:
            boundsDict[ens_id] = [bound_start, bound_end]
    return 0

def writeHeader():
    # Note the VISTA info is hardcoded because it is one and done

    fp.write(
'''##gff-version 3
#
# MGIreg.gff3
# Date: %s
# Taxonid: 10090
# Genome build: %s
#
# The MGIreg gff3 file is generated by combining information from multiple sources.
# Regulatory features and genome coordinates are obtained from VISTA and the Ensembl Regulatory Build.
# MGI transforms coordinates to genome build GRCm39 where necessary.
# Nomenclature, identifiers, and cross references come from MGI. Provider representations of regulatory
# features are preserved in MGI, with no attempt to identify regulatory feature equivalence between providers.
#
# The following lists information about the regulatory feature providers: the file, its modification date, and its URL
#
# ----------------------------------
#
# ensembl regulatory build
# File: %s
# File url: %s
# File date used: %s
#
# ----------------------------------
#
# VISTA
# File: VISTA.fasta
# File url: https://enhancer.lbl.gov/cgi-bin/imagedb3.pl?search.result=yes;form=search;action=search;page_size=20000;show=1;search.form=no;search.org=Mouse;search.sequence=1
# File date used: 2022-03-24 
#\n''' % (date, mAssembly, baseEnsemblGFF, ensemblGFFUrl, ensemblGFFTimeStamp))

def writeGffFile():

    # static columns
    column6 = '.'
    column7 = '.'
    column8 = '.'

    # variable columns
    column1 = ''     # genomic chromosome
    column2 = ''     # source ENSEMBL or VISTA
    column3 = ''     # SO term
    column4 = ''     # startCoordinate
    column5 = ''     # endCoordinate
    column9 = ''

    # template for column nine
    column9EnsTemplate = 'ID=%s; Name=%s; description=%s; curie=%s; Dbxref=%s; bound_start=%s; bound_end=%s; mgi_type=%s; so_term_name=%s'
    column9VisTemplate = 'ID=%s; Name=%s; description=%s; curie=%s; Dbxref=%s; mgi_type=%s; so_term_name=%s'
    # components of column 9
    iid = 'reg%s'           # some generated internal id
    name = ''               # marker symbol
    description = ''        # marker name
    curie = ''              # marker MGI ID
    mgi_type = ''           # mgi feature type (mcv term)

    # tack on to internal id
    generatedId = 0

    print('Writing gff file ...')
    sys.stdout.flush()

    # write out the file header
    writeHeader()
    
    print ('Rows in the input: %s' % len(finalResults))
    for r in finalResults:
        bound_start = ''
        bound_end = ''
        generatedId += 1
        displayId = str(generatedId).zfill(6)
        seqID = r['seqID']

        # get the SO term if the mcvID mapped to SO
        mcvID = r['mcvID']
        soTermName = ''
        if mcvID in mcvIdToSODict:
            soTermName = mcvIdToSODict[mcvID][1]

        # ldbname is what we want for VISTA, but must translate for Ensembl
        provider = r['provider']
        if r['_logicaldb_key'] == 222:
            provider = 'ENSEMBL'
        dbxref = '%s:%s' % ( provider, seqID)
        # get start and end as int
        startcoordinate = str(int(r['startcoordinate']))
        endCoordinate = str(int(r['endcoordinate']))
        if seqID in boundsDict:
            bound_start = boundsDict[seqID][0]
            bound_end = boundsDict[seqID][1]

        column1 = r['genomicchromosome']
        column2 = provider
        column3 = soTermName
        column4 = startcoordinate
        column5 = endCoordinate
        if provider == 'ENSEMBL':
            column9 = column9EnsTemplate % (iid % displayId, r['symbol'], r['name'], r['markerID'], dbxref, bound_start, bound_end, r['mcvTerm'], soTermName)
        else: # VISTA
            column9 = column9VisTemplate % (iid % displayId, r['symbol'], r['name'], r['markerID'], dbxref, r['mcvTerm'], soTermName)
        fp.write(column1 + TAB)
        fp.write(column2 + TAB)
        fp.write(column3 + TAB)
        fp.write(column4 + TAB)
        fp.write(column5 + TAB)
        fp.write(column6 + TAB)
        fp.write(column7 + TAB)
        fp.write(column8 + TAB)
        fp.write(column9 + CRT)

    return 0
#
# Main
#
init()
writeGffFile()
fp.close()
db.useOneConnection(0)
