const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const root=path.resolve(__dirname,'../public');
const context=vm.createContext({window:{},TextEncoder,Uint8Array,Uint32Array,DataView,Map,Set,Intl,Date,URLSearchParams,console,fetch:async url=>({ok:true,json:async()=>JSON.parse(fs.readFileSync(path.join(root,url),'utf8'))})});
for(const file of ['lessons.js','library-index.js','book-profiles.js','study-paths.js','stories.js','book-studies.js','library.js','story-reader.js','weekly-docx.js'])vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),context,{filename:file});
(async()=>{await vm.runInContext(`(async()=>{
if(bibleBooks.length!==66||bookProfiles.length!==66||CHAPTER_STUDIES!==1196||bibleStories.length!==168+bibleBookStudies.length)throw Error('Library totals');
let chapters=0,verses=0;
for(let b=0;b<66;b++){const data=await loadBook(b);if(data.chapters.length!==bibleBooks[b].chapters)throw Error('Book length '+b);for(let c=1;c<=data.chapters.length;c++){const ch=data.chapters[c-1];chapters++;verses+=ch.verses.length;if(!ch.commentary.length||!ch.verses.length)throw Error('Missing content '+b+':'+c);const study=await prepareStudy(chapterId(b,c));if(study.title!==bibleBooks[b].name+' '+c||study.questions.length!==3)throw Error('Study shape');}}
if(chapters!==1189||verses!==31102)throw Error('Scripture totals');
for(const p of [...topicPaths,...characterPaths])for(const [b,c]of p[3])if(!bibleBooks[b]||c<1||c>bibleBooks[b].chapters)throw Error('Path reference '+p[0]);
if(weekStart('2026-11-08')!=='2026-11-02'||weekStart('2026-11-09')!=='2026-11-09'||weekStart('2027-01-01')!=='2026-12-28')throw Error('Monday week boundary');
if(localStudyDate('2026-11-08T23:30:00Z')!=='2026-11-09')throw Error('Cameroon midnight');
for(const [q,b,c,v]of [['John 3:16',42,3,16],['Psalm 23',18,23,0],['1 John 1',61,1,0],['Revelation 22',65,22,0]]){const r=parseReference(q);if(!r||r.book!==b||r.chapter!==c||r.verse!==v)throw Error('Reference '+q)}
if(parseReference('John 99'))throw Error('Invalid reference accepted');
const id=chapterId(18,23),lesson=await prepareStudy(id);window.qaDocx=buildStudyDocx([{id,lesson}],{from:'2026-11-02',to:'2026-11-08',mode:'journal',includeBible:true,includeCommentary:true,notes:{[id]:{q0:'The Lord leads me. I will pray before work & listen carefully.',response:'Thank You, Father, for Your care. Help me trust You today.'}},progress:[id]});
return {books:bibleBooks.length,chapters,verses,studies:TOTAL_STUDIES,topics:topicPaths.length,characters:characterPaths.length,docxBytes:window.qaDocx.length};
})()`,context).then(result=>console.log(JSON.stringify(result)));fs.writeFileSync('/workspace/quiet-time-qa.docx',context.window.qaDocx);
})();
