
'''
# Report:
#       Tab-delimited file of Ensembl, NCBI, VISTA regulatory region coordinates
#       (Cre and More Project (CREAM))
#
#   1. chromosome
#   2. source of feature: mrk_location_cache.provider
#   3. gene feature: if NCBI, use GFF/field 3, else use SO Term Name
#   4. start coordinate
#   5. end coordinate
#   6. score: '.'
#   7. strand: '.'
#   8. frame: '.'
#   9. feature attributes: Creator; Sequence_tag_ID; GenBank_ID; DBxref; Type
#	  where: 
#         'ID' an internal ID
#   	  'Name' Marker Symbol
#	  'description' Marker name
#         'curie' Marker MGI ID
#	  'Dbxref'  ENSEMBL, NCBI, VISTA IDs
#	  'bound_start ENSEMBL, NCBI from the ensembl/ncbi regulatory gff file
#     'bound_end ENSEMBL, NCBI from the ensembl/ncbi regulatory gff file
#     VISTA: no bounds
#     'mgi_type MGI feature type
#     'so_term_name SO term
#
# Usage:
#     ${PYTHON} MGIreg.gff3.py 
#
# 1. Search MGI for all Mouse Marker with Ensembl (222) and VISTA (223) 
#       where marker status = 'official'
# 2. Search MGI for all Mouse Marker with NCBS (59), 
#       where marker status = 'official' 
#       and provider = 'NCBI' 
#       and marker type = 'Other Genome Feature'
# 3. Search Ensembl GFF and save Seq ID , field 3 (gff term), bound_start, bound_end where:
#       where line contains 'ID', 'bound_start', 'bound_end'
# 4. Search NCBI GFF and save Seq ID, field 3 (gff term), field 4 (bound_end), field 5 (bound_start) where:
#       where line contains 'RefSeqFE' and 'Dbxref=GeneID:'
# 5. For each Marker in (1&2): 
#   a. if VISTA, then use VISTA Marker info from MGI (1)
#   b. if Ensembl then use Ensembl Marker info from MGI (1) and GFF (3)
#   c. if NCBI, then use NCBI Marker info from MGI (3) and GFF (4)
# 6. For VISTA, there is 1 MGI row per Marker
# 7. For Ensembl, there is 1 GFF row per Marker
# 8. For NCBI, there can be >= 1 GFF row per Marker
#
# History:
#
# 08/29/2024    lec
#   wts2-1538/fl2-951/Add NCBI regulatory regions/biological_region to MGIreg.gff3 file
#
# 5/18/2022 sc - created
#
'''
 
import sys
import os
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

# end ENSEMBL GFF Configuration

# NCBI GFF Configuration

# zipped version of NCBI gff - filename from source
sourceNcbiGFF = os.getenv('NCBI_GFF')

# local unzipped sourceNcbiGFF file from which to parse bounds
ncbiGFF = os.getenv('NCBI_GFF_DEFAULT')

# just the file name w/o extension
baseNcbiGFF = os.path.splitext(os.path.basename(sourceNcbiGFF))[0]

# URL from which we get sourceNCBIGFF
ncbiGFFUrl = os.getenv('NCBI_GFF_URL')

# creation time of sourceNCBIGFF
ncbiGFFTimeStamp = time.ctime(os.path.getmtime(sourceNcbiGFF))

# end NCBI GFF Configuration

# where to write the gff file and its name
outputDir = os.getenv('OUTPUTDIR')
fileName = 'MGIreg.gff3'

# mapping of MCV ID to SO ID and Term
mcvIdToSODict = {}

# mapping of Ensembl ID, NCBI ID to 1 or more bound_start and bound_end 
# from ensembl regulatory, ncbi gff file
boundDict = {}

def init():
    global fp, finalResults
    
    db.useOneConnection(1)
    fp = open('%s/%s' % (outputDir, fileName), 'w')

    #
    # create MCV & SO ID lookup
    #
    results = db.sql('''
        select a1.accid as mcvID, a2.accid as soID, 
            t1._term_key as mcvTermKey, t1.term as mcvTerm, 
            t3.term as soTerm, t3._term_key as sotermKey
        from acc_accession a1, voc_term t1, acc_accession a2, acc_accession a3, voc_term t3
        where a1._logicaldb_key = 146
        and a1._mgitype_key = 13
        and a1._object_key = t1._term_key
        and t1._term_key = a2._object_key
        and a2._mgitype_key = 13
        and a2._logicaldb_key = 145
        and a2.accid = a3.accid
        and a3._mgitype_key = 13
        and a3._logicaldb_key = 145
        and a3._object_key = t3._term_key
        and t3._vocab_key = 138
        ''', 'auto')
    for r in results:
        mcvIdToSODict[r['mcvID']] = [r['soID'], r['soTerm']]

    db.sql('''
        (
        select a1.accid as seqID, a1._logicaldb_key, a2.accid as markerID,
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
        and a2.preferred = 1
        and c._marker_key = m._marker_key
        and m._marker_status_key = 1
        and m._marker_type_key = t._marker_type_key
        and c._marker_key = mcv._marker_key
        and mcv.qualifier = 'D' 
        union
        select a1.accid as seqID, a1._logicaldb_key, a2.accid as markerID,
            c.provider, c.genomicchromosome, c. startcoordinate, 
            c.endcoordinate, c.strand, m.symbol, m.name, t.name as markerType, 
            mcv.term as mcvTerm
        from mrk_location_cache c, acc_accession a1, acc_accession a2, 
            mrk_marker m, mrk_mcv_cache mcv, mrk_types t
        where a1._logicaldb_key in (59)
        and a1._mgitype_key = 2
        and a1._object_key = c._marker_key
        and c.provider = 'NCBI'
        and a1._object_key = a2._object_key
        and a2._mgitype_key = 2
        and a2._logicaldb_key = 1
        and a2.preferred = 1
        and c._marker_key = m._marker_key
        and m._marker_status_key = 1
        and m._marker_type_key = 9
        and m._marker_type_key = t._marker_type_key
        and c._marker_key = mcv._marker_key
        and mcv.qualifier = 'D' 
        )
        ''', None)

    db.sql('''create index idx1 on ev(mcvTerm)''', None)

    finalResults = db.sql('''
        select ev.*, a.accid as mcvID 
        from ev, voc_term t, acc_accession a
        where ev.mcvTerm = t.term
        and t._term_key = a._object_key
        and a._mgitype_key = 13
        and a._logicaldb_key = 146
        order by ev.genomicchromosome, ev.startcoordinate 
        ''', 'auto')

    # Create lookup of bounds by ensembl id
    fpE = open(ensemblGFF, 'r', encoding='latin-1')
    for line in fpE:
        ens_id = '' 
        bound_start = ''
        bound_end = ''
        tokens = str.split(line, TAB)
        gffTerm = tokens[2]
        col9 = tokens[8]
        fields = str.split(col9, ';')
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
            if ens_id not in boundDict:
                boundDict[ens_id] = []
            boundDict[ens_id].append([bound_start, bound_end, gffTerm])

    # Create lookup of bounds by ncbi id
    fpN = open(ncbiGFF, 'r', encoding='latin-1')
    for line in fpN:
        if line.startswith('#'):
            continue
        if line.find('RefSeqFE') < 0:
            continue
        if line.find('Dbxref=GeneID:') < 0:
            continue
        ncbi_id = ''
        bound_start = ''
        bound_end = ''
        tokens = str.split(line, TAB)
        gffTerm = tokens[2]
        bound_start = tokens[4]
        bound_end = tokens[3]
        t1 = str.split(line, 'Dbxref=GeneID:')
        t2 = t1[1].split(';')
        ncbi_id = t2[0]

        if ncbi_id == '' or bound_start == '' or bound_end == '':
            print('Missing: ncbi_id: %s bound_start: %s bound_end: %s' % (ncbi_id, bound_start, bound_end))
        else:
            if ncbi_id not in boundDict:
                boundDict[ncbi_id] = []
            boundDict[ncbi_id].append([bound_start, bound_end, gffTerm])

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
# Regulatory features and genome coordinates are obtained from VISTA, the Ensembl Regulatory Build & NCBI Regulatory Build.
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
# ncbi regulatory build
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
#\n''' % (date, mAssembly, baseEnsemblGFF, ensemblGFFUrl, ensemblGFFTimeStamp, baseNcbiGFF, ncbiGFFUrl, ncbiGFFTimeStamp))

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
    column9 = ''     # extra information

    # template for column nine
    column9EnsTemplate = 'ID=%s;Name=%s;description=%s;curie=%s;Dbxref=%s;bound_start=%s;bound_end=%s;mgi_type=%s;so_term_name=%s'
    column9NcbiTemplate1 = 'ID=%s;Name=%s;description=%s;curie=%s;Dbxref=%s;bound_start=%s;bound_end=%s;mgi_type=%s;so_term_name=%s'
    column9NcbiTemplate2 = 'ID=%s;Name=%s;description=%s;curie=%s;Dbxref=%s;bound_start=%s;bound_end=%s'
    column9VisTemplate = 'ID=%s;Name=%s;description=%s;curie=%s;Dbxref=%s;mgi_type=%s;so_term_name=%s'

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
        elif r['_logicaldb_key'] == 59:
            provider = 'NCBI'
        dbxref = '%s:%s' % ( provider, seqID)

        # get start and end as int
        startcoordinate = str(int(r['startcoordinate']))
        endCoordinate = str(int(r['endcoordinate']))

        column1 = r['genomicchromosome']
        column2 = provider
        column4 = startcoordinate
        column5 = endCoordinate

        # only 1 GFF row per Marker
        if provider == 'VISTA':

            column3 = soTermName
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
            continue

        # > 1 GFF row per Marker
        if seqID in boundDict:

            #print MGI level row here

            for b in boundDict[seqID]:
                bound_start = b[0]
                bound_end = b[1]
                gffTerm = b[2]

                if provider == 'ENSEMBL':
                    column3 = soTermName
                    column9 = column9EnsTemplate % (iid % displayId, r['symbol'], r['name'], r['markerID'], dbxref, bound_start, bound_end, r['mcvTerm'], soTermName)
                elif provider == 'NCBI':
                    column3 = gffTerm
                    if column3 == 'biological_region':
                        column9 = column9NcbiTemplate1 % (iid % displayId, r['symbol'], r['name'], r['markerID'], dbxref, bound_start, bound_end, r['mcvTerm'], soTermName)
                    else:
                        column9 = column9NcbiTemplate2 % (iid % displayId, r['symbol'], r['name'], r['markerID'], dbxref, bound_start, bound_end)

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
