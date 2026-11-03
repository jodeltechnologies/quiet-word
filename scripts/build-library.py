from pathlib import Path
from lxml import etree as E
from collections import defaultdict
import json,re,html,hashlib
root=Path(__file__).resolve().parents[1]; raw=root/'source-data';out=root/'public/data';out.mkdir(exist_ok=True)
bible=json.loads((raw/'kjv.json').read_text())['books']
r=E.parse(str(raw/'mhcc.xml'),E.XMLParser(resolve_entities=False,no_network=True,recover=True))
commentbooks=r.xpath('//ThML.body/div1[div2]')[:66]
def txt(el):return re.sub(r'\s+',' ',''.join(el.itertext())).strip()
def clean(s):return re.sub(r'\{[^{}]*\}','',html.unescape(s)).strip()
meta=[];missing=[]
for bi,(b,cb) in enumerate(zip(bible,commentbooks)):
 chapters=[{'verses':[clean(v['text']) for v in c['verses']],'outline':[],'commentary':[]} for c in b['chapters']]
 containers=list(cb.findall('div2'))
 if containers and containers[0].get('title')=='Chapter 2':
  import copy
  first=E.Element('div2',title='Chapter 1')
  for child in cb:
   if child.tag=='div2':break
   if child.tag!='h1':first.append(copy.deepcopy(child))
  containers.insert(0,first)
 for d in containers:
  m=re.search(r'(\d+)',d.get('title',''));default_c=int(m.group(1)) if m else 1
  for row in d.xpath('./table//tr'):
   cells=row.findall('td')
   if len(cells)<2:continue
   title=txt(cells[0]);refs=cells[1].xpath('.//scripRef')
   if not title or not refs:continue
   parsed=refs[0].get('parsed','').split('|');cn=int(parsed[2]) if len(parsed)>2 and parsed[2].isdigit() else default_c
   if 1<=cn<=len(chapters):chapters[cn-1]['outline'].append({'title':title,'range':txt(cells[1]).strip('()')})
  for div in d.xpath('./div[@class="Commentary"]'):
   prev=div.getprevious();parsed=(prev.get('parsed','') if prev is not None else '').split('|')
   cn=int(parsed[2]) if len(parsed)>2 and parsed[2].isdigit() else default_c
   if not 1<=cn<=len(chapters):continue
   title=txt(div.find('h3')) if div.find('h3') is not None else 'Chapter notes'
   ps=[txt(p) for p in div.findall('p') if txt(p)]
   if ps:chapters[cn-1]['commentary'].append({'heading':title,'paragraphs':ps})
  # Some source chapters use plain paragraphs instead of Commentary blocks.
  direct=[txt(p) for p in d.findall('p') if txt(p)]
  fallback=[p for p in direct if len(p)>140] or direct
  targets=[int(n) for n in re.findall(r'\d+',d.get('title',''))] or [default_c]
  for cn in targets:
   if 1<=cn<=len(chapters) and not chapters[cn-1]['commentary'] and fallback:
    chapters[cn-1]['commentary']=[{'heading':'Chapter explanation','paragraphs':fallback}]
    if not chapters[cn-1]['outline']:
     short=[p for p in direct if len(p)<=140]
     chapters[cn-1]['outline']=[{'title':p,'range':''} for p in short[:4]]
 intro=[txt(p) for p in cb.findall('p') if txt(p)] if len(containers)==len(cb.findall('div2')) else []
 for ci,ch in enumerate(chapters):
  if not ch['commentary']:missing.append((b['name'],ci+1))
  if not ch['outline'] and ch['commentary']:ch['outline']=[{'title':x['heading'],'range':''} for x in ch['commentary']]
 data={'name':cb.get('title'),'intro':intro,'chapters':chapters}
 (out/f'{bi:02}.json').write_text(json.dumps(data,ensure_ascii=False,separators=(',',':')))
 meta.append({'id':bi,'name':cb.get('title'),'chapters':len(chapters),'testament':'Old Testament' if bi<39 else 'New Testament','intro':intro,'titles':[' · '.join(o['title'].rstrip('.') for o in c['outline'][:2]) or f"{b['name']} {i+1}" for i,c in enumerate(chapters)]})
(root/'public/library-index.js').write_text('const bibleBooks='+json.dumps(meta,ensure_ascii=False,separators=(',',':'))+';\n')
provenance={'bible':{'name':'King James Version (1769)','source':'https://github.com/scrollmapper/bible_databases','download':'https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/KJV.json','sha256':hashlib.sha256((raw/'kjv.json').read_bytes()).hexdigest()},'commentary':{'name':"Matthew Henry’s Concise Commentary on the Whole Bible",'source':'https://www.ccel.org/ccel/henry/mhcc.xml','rights':'Public Domain, as declared in the source DC.Rights metadata','sha256':hashlib.sha256((raw/'mhcc.xml').read_bytes()).hexdigest(),'note':'Only the public-domain commentary body was extracted. The modern editorial description and site content are excluded.'},'books':len(bible),'chapters':sum(len(b['chapters']) for b in bible),'verses':sum(len(c['verses']) for b in bible for c in b['chapters'])}
(root/'public/data/sources.json').write_text(json.dumps(provenance,indent=2))
print(json.dumps({'books':len(meta),'chapters':provenance['chapters'],'verses':provenance['verses'],'missingCommentary':missing,'dataBytes':sum(p.stat().st_size for p in out.glob('*.json'))}))
