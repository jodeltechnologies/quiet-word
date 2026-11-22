import json,re,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[1];P=R/'public';D=P/'story-data';D.mkdir(exist_ok=True)
books=[json.loads((P/f'data/{b:02}.json').read_text())for b in range(66)]
codes={'Gen':0,'Ex':1,'Lev':2,'Num':3,'Deu':4,'Josh':5,'Judg':6,'Ruth':7,'1Sam':8,'2Sam':9,'1Kings':10,'2Kings':11,'1Chr':12,'2Chr':13,'Ezra':14,'Neh':15,'Esth':16,'Job':17,'Ps':18,'Isa':22,'Jer':23,'Ezek':25,'Dan':26,'Jon':31,'Hag':36,'Matt':39,'Mark':40,'Luke':41,'John':42,'Acts':43,'Rev':65}
def refs(raw):
 out=[]
 for term in raw.split(';'):
  m=re.fullmatch(r'([A-Za-z0-9]+?)(\d+)(?:-(\d+))?',term)
  if not m or m[1]not in codes:raise ValueError(raw)
  b=codes[m[1]]
  for c in range(int(m[2]),int(m[3]or m[2])+1):
   assert 1<=c<=len(books[b]['chapters']),(raw,c)
   out.append([b,c])
 return out
def citation(chapters):
 groups=[]
 for b,c in chapters:
  if groups and groups[-1][0]==b and groups[-1][-1]+1==c:groups[-1].append(c)
  else:groups.append([b,c])
 return '; '.join(books[g[0]]['name']+' '+str(g[1])+('–'+str(g[-1])if len(g)>2 else '')for g in groups)
rows={x.split('|')[0]:x.split('|')[1:]for x in(R/'source/story-map.txt').read_text().splitlines()}
raw=json.loads((R/'source/retellings.json').read_text());stories=[]
for n,s in enumerate(raw):
 code,focus,lesson,question=rows[s['slug']];chapters=refs(code)
 body=dict(story=s['story'],source='Jesse Lyman Hurlbut, Story of the Bible, 1904. Distributed by Heritage History 2009.',sourceUrl=s['url'])
 (D/f'{n:03}.json').write_text(json.dumps(body,ensure_ascii=False,separators=(',',':')))
 stories.append(dict(id=90000+n,title=s['title'],subtitle=focus,text=citation(chapters),chapters=chapters,kind='story',category='Old Testament'if n<109 else 'Jesus and His teaching'if n<147 else 'The early church and Revelation',file=f'{n:03}',lesson=lesson,question=question,wordCount=sum(len(p.split())for p in s['story']),source='Hurlbut 1904'))
featured=json.loads((R/'source/featured.json').read_text())
for n,s in enumerate(featured):
 body=dict(story=s.pop('story'),source='Original Quiet Time retelling based on the cited Scripture.',sourceUrl='')
 file='featured-'+str(n);(D/(file+'.json')).write_text(json.dumps(body,ensure_ascii=False,separators=(',',':')))
 s.update(kind='story',category='Guided spiritual studies',file=file,wordCount=sum(len(p.split())for p in body['story']),source='Quiet Time')
 stories.append(s)
# Coverage uses canonical verse coordinates, not the unstable position of an outline.
# Every biblical verse is assigned once even where an inherited outline has a typo.
scenes=[];verse_offset=0;coverage=[]
for b,book in enumerate(books):
 count=0
 for c,ch in enumerate(book['chapters'],1):
  starts={1};titles={}
  for o in ch['outline']:
   m=re.match(r'(\d+)',o['range'])
   if m and 1<=int(m[1])<=len(ch['verses']):starts.add(int(m[1]));titles[int(m[1])]=o['title'].rstrip('.')
  for block in ch['commentary']:
   m=re.match(r'Verses?\s+(\d+)',block['heading'])
   if m and 1<=int(m[1])<=len(ch['verses']):starts.add(int(m[1]))
  starts=sorted(starts)
  for k,start in enumerate(starts):
   end=starts[k+1]-1 if k+1<len(starts)else len(ch['verses'])
   title=titles.get(start)or next(iter(titles.values()),book['name']+' passage')
   typ='Story episode'if b in list(range(0,18))+[31,39,40,41,42,43]else 'Vision'if b in[25,26,65]else 'Teaching and context'
   if re.search(r'genealog|families|names of|laws? of|sacrifices|numbering',title,re.I):typ='Teaching and context'
   scenes.append(dict(id=50000+verse_offset+start-1,title=title,subtitle=typ,text=f'{book["name"]} {c}:{start}'+(f'–{end}'if end>start else ''),book=b,chapter=c,start=start,end=end,kind='scene',category=typ))
   count+=end-start+1
  verse_offset+=len(ch['verses'])
 total=sum(len(ch['verses'])for ch in book['chapters']);assert count==total
 coverage.append(dict(book=b,verses=total,covered=count,episodes=sum(s['book']==b for s in scenes)))
assert verse_offset==31102 and len(stories)==len(raw)+len(featured)
(P/'stories.js').write_text('/* Stable story IDs and verse-coordinate episode IDs. */\nconst bibleStories='+json.dumps(stories,ensure_ascii=False,separators=(',',':'))+';\nconst scriptureScenes='+json.dumps(scenes,ensure_ascii=False,separators=(',',':'))+';\nconst storyCoverage='+json.dumps(coverage,separators=(',',':'))+';\n')
(P/'story-data/sources.json').write_text(json.dumps(dict(retelling='Jesse Lyman Hurlbut, Story of the Bible, 1904',edition='Distributed by Heritage History 2009',originalCopyright='Original Copyright 1904 by Jesse Lyman Hurlbut',url='https://www.heritage-history.com/index.php?author=hurlbut&book=bible&c=read',use='Personal and educational use with attribution. Retelling text is reproduced without alteration. Historical retellings are interpretation, not biblical quotations.',retellingCount=168,originalStudyCount=len(featured),sceneCount=len(scenes),bibleVersesCovered=31102,sourceSha256=hashlib.sha256((R/'source/retellings.json').read_bytes()).hexdigest()),indent=2))
print(json.dumps(dict(retellings=len(stories),episodes=len(scenes),books=len(coverage),versesCovered=verse_offset,dataBytes=sum(p.stat().st_size for p in D.glob('*.json')))))
