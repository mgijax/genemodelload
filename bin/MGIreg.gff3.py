'''
#
# Report:
#       Tab-delimited MGIreg.gff3 file of Ensembl, NCBI, VISTA regulatory region coordinates
#
# The gff is generated each time the Ensembl Reg, VISTA Reg gene model associations are reloaded.
# see genemodelload.sh
#
# column1 = chromosome
# column2 = provider (MGI, Ensembl, NCBI, VISTA)
# column3 = MCV term
# column4 = start coordinate
# column5 = end coordiate
# column6 = .
# column7 = strand
# column8 = .
# column9 = comma-separated list from provider GFF file:
#   ID=
#   Name=
#   description=
#   gene_id=
#   mgi_type=
#   so_term_name=
#   Dbxref=
#   Synonym=
#   Parent=
#
# each provider requires:
#   . "MGI" master row : writeMGIRow()
#   . a parent row : writeParentRow()
#
# 1. Temp Tables to store info from MGI database: init()
#   set of Markers with MCV regulatory terms (mrk_location_cache)
#   sorted by start coordinate
#
# 2. Read/Create Lookups for Ensembl MGI, NCBI MGI, VISTA MGI : init()
#   the Marker Key:Provider ID
#
# 3. Read/Create Lookups for Ensembl GFF, NCBI GFF, VISTA GFF : initGFF()
#   
# 4. For each Marker:
#
#   Attach all provider ids to Marker Master DbxRef (Ensembl, NCBI, VISTA)
#
#   if Marker exists in Ensembl MGI, then add MGI Master, Ensembl Parent, NCBI Parent (if exists), VISTA Parent (if exists)
#   else if Marker exists in NCBI MGI, then add MGI Master, NCBI Parent, VISTA Parent (if exists)
#   else if Marker exists in VISTA MGI, then add MGI Master, VISTA Parent
#   else then add MGI Master, MGI Parent
#
# Usage:
#     ${PYTHON} MGIreg.gff3.py 
#
# History:
#
# 01/02/2025    lec     wts2-1538/e4g-9/MGI Regulatory GFF changes: MGIreg.gff3
#
'''
 
import sys
import os
import time
import mgi_utils
import reportlib
import db

db.setTrace()

CRT = reportlib.CRT
TAB = reportlib.TAB
date = mgi_utils.date('%m/%d/%Y %H:%M:%S') #("%Y-%m-%d")

# mapping of MCV ID to SO ID and Term
mcvToSOLookup = {}

ensemblMGI = {}
ncbiMGI = {}
vistaMGI = {}
ensemblInfo = {}
ncbiInfo = {}
vistaInfo = {}

idTag = 'ID='
nameTag = 'Name='
descTag = 'description='
geneIdTag = 'gene_id='
mgiTypeTag = 'mgi_type='
soTag = 'so_term_name='
dbxRefTag = 'Dbxref='
synonymTag = 'Synonym='
parentTag = 'Parent='

dbxRefEnsembl = 'Dbxref=ENSEMBL:'
dbxRefNCBI = 'Dbxref=GeneID:'
dbxRefVista = 'Dbxref=VISTA:'

mgiProvider = 'MGI:'
ensemblProvider = 'Ensembl'
ncbiProvider = 'NCBI'
vistaProvider = 'VISTA'

column1 = ''
column2 = ''
column3 = ''
column4 = ''
column5 = ''
column6 = '.'
column7 = ''
column8 = '.'
column9 = ''
columnSynonym = ''

def writeHeader():
    global fp

    mAssembly = os.getenv('MOUSE_ASSEMBLY')
    ensemblFile = os.getenv('ENSEMBL_FILE')
    ensembl = os.getenv('ENSEMBL_FTP')
    ncbiFile = os.getenv('NCBI_FILE')
    ncbi = os.getenv('NCBI_FTP')
    vistaFile = os.getenv('VISTA_FILE')
    vista = os.getenv('VISTA_FTP')
    ensemblTimeStamp = time.ctime(os.path.getmtime(os.getenv('ENSEMBL_GFF')))
    ncbiTimeStamp = time.ctime(os.path.getmtime(os.getenv('NCBI_GFF')))
    vistaTimeStamp = time.ctime(os.path.getmtime(os.getenv('VISTA_GFF')))

    fp.write('''#gff-version 3
# MGIreg.gff3
# Date: %s
# Taxonid: 10090
# Genome build: %s
#
# The MGIreg gff3 file is generated by combining information from multiple sources.
# Regulatory features and genome coordinates are obtained from NCBI, VISTA and the Ensembl Regulatory Build and manual curations at MGI.
# MGI transforms coordinates to genome build GRCm39 where necessary.
# Nomenclature, identifiers, and cross references come from MGI. Provider representations of regulatory
# features are preserved in MGI, with no attempt to identify regulatory feature equivalence between providers.
# 
# The following lists information about the provider files used to load regulatory features into MGI: the file, its modification date, and its URL
# ----------------------------------
# Ensembl Regulatory Build
# File: %s
# File url: %s
# File date used: %s
# 
# VISTA
# File: %s
# File url: %s
# File date used: %s
# 
# NCBI
# File: %s
# File url: %s
# File date used: %s
#
#
''' % (date, mAssembly, ensemblFile, ensembl, ensemblTimeStamp, vistaFile, vista, vistaTimeStamp, ncbiFile, ncbi, ncbiTimeStamp))

def init():
    global mcvToSOLookup
    global ensemblMGI, ncbiMGI, vistaMGI
    
    #
    # create SO ID to SO Term lookup
    #
    results = db.sql('''
        select a.accid as mcvID, t1.term as mcvTerm, a3.accid as soID, t2.term as soTerm
        from voc_term t1, acc_accession a, acc_accession a2, acc_accession a3, voc_term t2
        where a._logicaldb_key = 146
        and a._mgitype_key = 13
        and a._object_key = t1._term_key
        and t1._term_key = a2._object_key
        and a2._mgitype_key = 13
        and a2._logicaldb_key = 145
        and a2.accid = a3.accid
        and a3._mgitype_key = 13
        and a3._logicaldb_key = 145
        and a3._object_key = t2._term_key
        and t2._vocab_key = 138
        ''', 'auto')
    for r in results:
        soList = [r['soID'], r['soTerm']]
        mcvToSOLookup[r['mcvID']] = soList

    #
    # set of markers
    # markers in MRK_Location_Cache
    # where mcv term = regulatory term
    # save the mgiID, provider chromosome, start/end coordinates, strand, feature type, mcvID, etc.
    #
    db.sql('''
        select a.accid as markerID,
            c.provider, c.genomicchromosome as chromosome, c.startcoordinate, c.endcoordinate, c.strand, 
            m._marker_key, m.symbol, m.name, 
            t.term as featureType, mcv.term as mcvTerm, av.accid as mcvID,
            '' as soTermName
        into temp table markers
        from mrk_location_cache c, acc_accession a, mrk_marker m, 
            mrk_mcv_cache mcv, voc_annot va, voc_term t, acc_accession av
        where c._marker_key = a._object_key
        and a._mgitype_key = 2
        and a._logicaldb_key = 1
        and a.preferred = 1
        and c._marker_key = m._marker_key
        and c.provider is not null
        -- MCV/Marker _vocab_key = 79
        and m._marker_key = va._object_key
        and va._annottype_key = 1011
        and va._term_key = t._term_key
        and c._marker_key = mcv._marker_key
        and mcv.qualifier = 'D' 
        and mcv._mcvterm_key = av._object_key
        and av._mgitype_key = 13
        and av._logicaldb_key = 146
        and mcv.term in (
            'CTCF binding site',	
            'enhancer',	
            'histone modification',	
            'imprinting control region',
            'insulator',
            'intronic regulatory region',
            'insulatorresponse', 
            'insulator binding site',	
            'locus control region',
            'matrix attachment site',	
            'open chromatin region',
            'origin of replication',
            'promoter',
            'promoter flanking region region',	
            'response element',
            'silencer',
            'splice enhancer',
            'transcriptional cis regulatory region',
            'transcription factor binding site'
            )
        --and a.accid in ('MGI:6889016')
        order by c.chromosome, c.startcoordinate
        ''', 'auto')

    db.sql('''create index kidx1 on markers(_marker_key)''', None)
    db.sql('''create index kidx2 on markers(provider)''', None)

    # Ensembl by Marker key
    ensemblMGI = {}
    results = db.sql('''
        select m._marker_key, p.accid
        from markers m, acc_accession p
        where m._marker_key = p._object_key
        and p._mgitype_key = 2
        and p._logicaldb_key = 222
        ''', 'auto')
    for r in results:
        key = r['_marker_key']
        value = r['accid']
        if key not in ensemblMGI:
            ensemblMGI[key] = []
        ensemblMGI[key].append(value)

    # NCBI by Marker key
    ncbiMGI = {}
    results = db.sql('''
        select m._marker_key, p.accid
        from markers m, acc_accession p
        where m._marker_key = p._object_key
        and p._mgitype_key = 2
        and p._logicaldb_key = 59
        ''', 'auto')
    for r in results:
        key = r['_marker_key']
        value = r['accid']
        if key not in ncbiMGI:
            ncbiMGI[key] = []
        ncbiMGI[key].append(value)

    # VISTA by Marker key
    vistaMGI = {}
    results = db.sql('''
        select m._marker_key, p.accid
        from markers m, acc_accession p
        where m._marker_key = p._object_key
        and p._mgitype_key = 2
        and p._logicaldb_key = 223
        ''', 'auto')
    for r in results:
        key = r['_marker_key']
        value = r['accid']
        if key not in vistaMGI:
            vistaMGI[key] = []
        vistaMGI[key].append(value)

def initGFF():
    global ensemblInfo
    global ncbiInfo
    global vistaInfo

    ensemblGFF = os.getenv('ENSEMBL_GFF_DEFAULT')
    fpProvider = open(ensemblGFF, 'r', encoding='latin-1')
    for line in fpProvider:
        if line.startswith('#'):
            continue
        tokens = str.split(line, TAB)
        t1 = str.split(tokens[8], ';')
        idTokens = t1[0].split(':')
        id = idTokens[1]
        mcvterm = tokens[2]
        startcoordinate = tokens[3]
        endcoordinate = tokens[4]
        strand = tokens[5]
        dbxRef = id + ';' + t1[1] + ';' + t1[2] + ';' + t1[3] + ';' + t1[4]
        dbxRef = dbxRef.replace('\n','')
        value = (mcvterm, startcoordinate, endcoordinate, strand, dbxRefEnsembl + dbxRef)
        if id not in ensemblInfo:
            ensemblInfo[id] = []
        ensemblInfo[id].append(value)
    fpProvider.close()
    #print(ensemblInfo)

    ncbiGFF = os.getenv('NCBI_GFF_DEFAULT')
    fpProvider = open(ncbiGFF, 'r', encoding='latin-1')
    for line in fpProvider:
        if line.startswith('#'):
            continue
        if line.find('biological_region') > 0:
            continue
        if line.find('RefSeqFE') < 0:
            continue
        tokens = str.split(line, TAB)
        # save dbxRef info
        t1 = str.split(line, dbxRefNCBI)
        t2 = t1[1].split(';')
        # remove ",xxxx" at the end
        t3 = t2[0].split(',')
        id = t3[0]
        mcvterm = tokens[2]
        startcoordinate = tokens[3]
        endcoordinate = tokens[4]
        strand = tokens[5]
        value = (mcvterm, startcoordinate, endcoordinate, strand, dbxRefNCBI + t1[1].replace('\n',''))
        if id not in ncbiInfo:
            ncbiInfo[id] = []
        ncbiInfo[id].append(value)
    fpProvider.close()
    #print(ncbiInfo)

    vistaGFF = os.getenv('VISTA_GFF_DEFAULT')
    fpProvider = open(vistaGFF, 'r', encoding='latin-1')
    for line in fpProvider:
        if line.startswith('#'):
            continue
        tokens = str.split(line, TAB)
        # save dbxRef info
        t1 = str.split(line, dbxRefVista)
        t2 = t1[1].split(';')
        # remove ",xxxx" at the end
        t3 = t2[0].split(',')
        id = t3[0]
        mcvterm = tokens[2]
        startcoordinate = tokens[3]
        endcoordinate = tokens[4]
        strand = tokens[5]
        value = (mcvterm, startcoordinate, endcoordinate, strand, dbxRefVista + t1[1].replace('\n',''))
        if id not in vistaInfo:
            vistaInfo[id] = []
        vistaInfo[id].append(value)
    fpProvider.close()
    #print(vistaInfo)

def setMGIColumns(r, dbx):
    global column1,column2,column3,column4,column5,column7,column9
    global columnSynonym

    column1 = r['chromosome']
    column2 = 'MGI'
    column3 = r['mcvterm']
    column4 = str(r['startcoordinate']).replace(".0", "")
    column5 = str(r['endCoordinate']).replace(".0", "")
    column7 = str(r['strand'])
    column9 = idTag + r['markerid'] + ';'
    column9 += nameTag + r['symbol'] + ';'
    column9 += descTag + r['name'] + ';'
    column9 += geneIdTag + r['markerid'] + ';'

    if r['provider'] == 'MGI':
        column9 += dbxRefTag + mgiProvider + r['markerid'] + ';'
    else:
        #column9 += dbxRefTag + r['provider'] + ':' + r['providerId'] + ';'
        column9 += dbxRefTag + dbx

    column9 += mgiTypeTag + r['featureType'] + ';'
    column9 += soTag + r['soTermName'] + ';'
    column9 += columnSynonym

def setParentColumns(provider,r,n,counter):
    global column2,column3,column4,column5,column7,column9

    column2 = provider
    column3 = n[0]
    column4 = n[1]
    column5 = n[2]
    column7 = n[3]
    column9 = idTag + r['markerid'] + '_' + str(counter) + ';'
    column9 += parentTag + r['markerid'] + ';'
    column9 += geneIdTag + r['markerid'] + ';'
    column9 += n[4]

def writeMGIRow():
    fp.write(column1 + TAB)
    fp.write(column2 + TAB)
    fp.write(column3 + TAB)
    fp.write(column4 + TAB)
    fp.write(column5 + TAB)
    fp.write(column6 + TAB)
    fp.write(column7 + TAB)
    fp.write(column8 + TAB)
    fp.write(column9 + CRT)

def writeParentRow():
    fp.write(column1 + TAB)
    fp.write(column2 + TAB)
    fp.write(column3 + TAB)
    fp.write(column4 + TAB)
    fp.write(column5 + TAB)
    fp.write(column6 + TAB)
    fp.write(column7 + TAB)
    fp.write(column8 + TAB)
    fp.write(column9 + CRT)

def processAll():
    global column1,column2,column3,column4,column5,column6,column7,column8,column9
    global columnSynonym

    synonyms = {}
    sresults = db.sql('''
        (
        select s._object_key as _marker_key, s.synonym, null as refid
        from markers m, mgi_synonym s
        where m._marker_key = s._object_key
        and s._mgitype_key = 2
        and s._refs_key is null
        union
        select s._object_key as _marker_key, s.synonym, array_to_string(array_agg(distinct 'PMID:'||r.pubmedid),',')
        from markers m, mgi_synonym s, bib_citation_cache r
        where m._marker_key = s._object_key
        and s._mgitype_key = 2
        and s._refs_key = r._refs_key
        and r.pubmedid is not null
        group by 1,2
        union
        select s._object_key as _marker_key, s.synonym, array_to_string(array_agg(distinct r.jnumid),',')
        from markers m, mgi_synonym s, bib_citation_cache r
        where m._marker_key = s._object_key
        and s._mgitype_key = 2
        and s._refs_key = r._refs_key
        and r.pubmedid is null
        group by 1,2
        )
        ''', 'auto')
    for r in sresults:
        key = r['_marker_key']
        value = r
        if key not in synonyms:
            synonyms[key] = []
        synonyms[key].append(value)
    #print(str(len(synonyms)))

    results = db.sql('''select * from markers ''', 'auto')

    # for each marker in results
    for r in results:
        key = r['_marker_key']

        # get the SO term if the mcvID mapped to SO
        mcvID = r['mcvID']
        r['soTermName'] = ''
        if mcvID in mcvToSOLookup:
            r['soTermName'] = mcvToSOLookup[mcvID][1]

        if r['strand'] == None:
            r['strand'] = ''

        # Synonym=synonym1[Ref_ID:1, Ref_ID:2,etc,],
        columnSynonym = ''
        if key in synonyms:
            prepSynonym = synonymTag
            for s in synonyms[key]:
                prepSynonym += ',' + s['synonym']
                if s['refid'] != None:
                    prepSynonym += '[Ref_ID:' + s['refid'] + ']'
            prepSynonym = prepSynonym.replace("=,","=")
            columnSynonym += prepSynonym

        # parent row

        # if marker contains Ensembl
        if key in ensemblMGI:

            id = ensemblMGI[key][0]
            nid = ''
            vid = ''

            # mgi row
            dbxinfo = []
            dbxinfo.append(ensemblProvider + ':' + id)
            if key in ncbiMGI:
                nid = ncbiMGI[key][0]
                dbxinfo.append(ncbiProvider + ':' + nid)
            if key in vistaMGI:
                vid = vistaMGI[key][0]
                dbxinfo.append(vistaProvider + ':' + vid)
            dbx = ",".join(dbxinfo) + ';'
            setMGIColumns(r, dbx)
            writeMGIRow()

            counter = 1

            # parent row
            if id not in ensemblInfo:
                print('not in ensembl gff: ', id)
                continue

            for n in ensemblInfo[id]:
                setParentColumns(ensemblProvider,r,n,counter)
                writeParentRow()
                counter += 1

            # parent row
            if nid != '':
                for n in ncbiInfo[nid]:
                    setParentColumns(ncbiProvider,r,n,counter)
                    writeParentRow()
                    counter += 1

            # parent row
            if vid != '':
                for n in vistaInfo[vid]:
                    setParentColumns(vistaProvider,r,n,counter)
                    writeParentRow()
                    counter += 1

        # if marker contains NCBI
        elif key in ncbiMGI:

            id = ncbiMGI[key][0]
            vid = ''

            # mgi row
            dbxinfo = []
            dbxinfo.append(ncbiProvider + ':' + id)
            if key in vistaMGI:
                vid = vistaMGI[key][0]
                dbxinfo.append(vistaProvider + ':' + vid)
            dbx = ",".join(dbxinfo) + ';'
            setMGIColumns(r, dbx)
            writeMGIRow()

            counter = 1

            # parent row
            for n in ncbiInfo[id]:
                setParentColumns(ncbiProvider,r,n,counter)
                writeParentRow()
                counter += 1

            # parent row
            if vid != '':
                for n in vistaInfo[vid]:
                    setParentColumns(vistaProvider,r,n,counter)
                    writeParentRow()
                    counter += 1

        elif key in vistaMGI:

            id = vistaMGI[key][0]

            # mgi row
            setMGIColumns(r, vistaProvider + ':' + id + ';')
            writeMGIRow()

            counter = 1

            # parent row
            for n in vistaInfo[id]:
                setParentColumns(vistaProvider,r,n,counter)
                writeParentRow()
                counter += 1

        # else marker is single
        else:
            # mgi row
            setMGIColumns(r, r['provider'] + ':' + r['markerID'] + ';')
            writeMGIRow()

            column9 = idTag + r['markerid'] + '_1;'
            column9 += parentTag + r['markerid'] + ';'
            column9 += geneIdTag + r['markerid'] + ';'
            column9 += dbxRefTag + mgiProvider + r['markerid']
            writeParentRow()

#
# Main
#
fp = open(os.getenv('OUTPUTDIR') + '/MGIreg.gff3', 'w')
writeHeader();
init()
initGFF()
processAll()
fp.close()

