from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
from urllib.parse import urlsplit,parse_qs
import urllib.request,json,re,html,time
root=Path('/workspace/quiet-time-story');src=root/'source';src.mkdir(exist_ok=True)
if not(src/'links.json').exists():
 with urllib.request.urlopen('https://www.heritage-history.com/index.php?author=hurlbut&book=bible&c=read',timeout=20)as r:data=r.read()
 text=data.decode('utf8','replace')
 anchors=re.findall(r'<a[^>]+href=[\"\']([^\"\']+)[\"\'][^>]*>(.*?)</a>',text,re.S|re.I)
 (src/'links.json').write_text(json.dumps([dict(url=html.unescape(href),title=html.unescape(re.sub('<[^>]+>','',title)))for href,title in anchors if 'story='in href]))
rows=json.loads((src/'links.json').read_text());unique={}
for row in rows:
 slug=parse_qs(urlsplit(row['url']).query)['story'][0]
 if slug!='_front' and slug not in unique:unique[slug]=row
rows=list(unique.items())
def get(item):
 slug,row=item;p=src/(slug+'.html')
 if not p.exists():
  for attempt in range(3):
   try:
    with urllib.request.urlopen(row['url'],timeout=20)as r:data=r.read()
    p.write_bytes(data);break
   except Exception:
    if attempt==2:raise
    time.sleep(1)
 data=p.read_bytes()
 try:s=data.decode('utf8')
 except UnicodeDecodeError:s=data.decode('cp1252')
 h=re.search(r'<h1[^>]*>(.*?)</h1>',s,re.S|re.I)
 if not h:raise ValueError(slug+' has no title')
 title=html.unescape(re.sub('<[^>]+>','',h[1])).strip()
 body=s[h.end():]
 body=body.split('id="backbutton"')[0]
 paras=[]
 for block in re.findall(r'<p\b[^>]*>(.*?)</p\s*>',body,re.S|re.I):
  if '<img' in block.lower() or 'caption' in block.lower():continue
  t=html.unescape(re.sub('<[^>]+>',' ',block));t=re.sub(r'\s+',' ',t).strip()
  if t and len(t)>20:paras.append(t)
 if sum(len(t.split())for t in paras)<80:raise ValueError(slug+' is unexpectedly short')
 return slug,dict(title=title,story=paras,url=row['url'])
found={}
with ThreadPoolExecutor(max_workers=5)as pool:
 futures={pool.submit(get,item):item for item in rows}
 for n,f in enumerate(as_completed(futures),1):
  slug,row=f.result();found[slug]=row
  if n%24==0:print('Retellings loaded',n,flush=True)
ordered=[dict(slug=slug,**found[slug])for slug,row in rows]
(root/'source/retellings.json').write_text(json.dumps(ordered,ensure_ascii=False))
print('Complete',len(ordered),'Words',sum(len(' '.join(s['story']).split())for s in ordered),flush=True)
