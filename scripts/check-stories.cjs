const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const root=path.resolve(__dirname,'../public'),nodes=new Map();
function element(key){if(!nodes.has(key))nodes.set(key,{innerHTML:'',textContent:'',value:'',hidden:false,style:{},classList:{toggle(){}},events:{},addEventListener(t,f){this.events[t]=f},setAttribute(k,v){this[k]=v},click(){this.onclick?.()},showModal(){},close(){}});return nodes.get(key)}
const document={querySelector:element,getElementById:id=>element('#'+id),querySelectorAll:s=>s==='[data-key]'?['q0','q1','q2','response'].map(k=>Object.assign(element('#'+k),{dataset:{key:k},value:''})):[],body:{classList:{toggle(){}}},documentElement:{style:{setProperty(){}}},activeElement:null};
const cloud={unlocked:true,capture(){this.captured=true},async sync(){}};
const context=vm.createContext({window:{cloud,addEventListener(){},scrollTo(){}},cloud,document,navigator:{},localStorage:{getItem(){return null},setItem(){}},location:{hash:'#home'},TextEncoder,TextDecoder,Uint8Array,Uint32Array,DataView,Map,Set,Intl,Date,URLSearchParams,console,setTimeout(){},clearTimeout(){},fetch:async url=>({ok:true,json:async()=>JSON.parse(fs.readFileSync(path.join(root,url),'utf8'))})});
for(const file of ['lessons.js','library-index.js','book-profiles.js','study-paths.js','stories.js','gospel-retellings.js','library.js','library-ui.js','story-reader.js','weekly-docx.js','app.js'])vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),context,{filename:file});
(async()=>{const result=await vm.runInContext(`(async()=>{
if(bibleStories.length!==171+gospelRetellings.length||scriptureScenes.length!==3705)throw Error('Catalogue totals');
const seen=new Set();let verses=0;
for(const s of scriptureScenes){const book=await loadBook(s.book),ch=book.chapters[s.chapter-1];if(s.start<1||s.end>ch.verses.length||s.end<s.start)throw Error('Bad episode');for(let v=s.start;v<=s.end;v++){const key=s.book+':'+s.chapter+':'+v;if(seen.has(key))throw Error('Duplicate coverage');seen.add(key);verses++}}
if(verses!==31102||storyCoverage.some(x=>x.covered!==x.verses))throw Error('Coverage gap');
for(const s of bibleStories){const l=await prepareStudy(s.id);if(!l.story.length||!l.verses.length||l.questions.length!==3||!l.meaning.length)throw Error('Incomplete story '+s.id);for(const[b,c]of s.chapters)if(!bibleBooks[b]||c<1||c>bibleBooks[b].chapters)throw Error('Invalid reference')}
renderStoryHome();if(!app.innerHTML.includes('Stories from your examples')||!app.innerHTML.includes('The Prophet Who Turned Back'))throw Error('Home presentation');
$('#storyCollection').value='retellings';$('#storyBook').value='all';$('#storyQuery').value='';renderStoryCollection();if(!$('#storyCount').textContent.includes(String(bibleStories.length)))throw Error('Story listing');
$('#storyQuery').value='The Prophet Who Turned Back';$('#storyQuery').events.input();if(!$('#storyCount').textContent.includes('1 of 1'))throw Error('Search');
for (const s of gospelRetellings) {
  const study = await prepareStudy(s.id);
  if (study.verses.length !== s.end - s.start + 1 || study.verses[0][0] !== s.text.split('–')[0]) throw Error('Incorrect Gospel verse range: ' + s.text);
}
$('#storyQuery').value='';
renderStoryCollection(40);
if ($('#storyCollection').value !== 'gospels' || !$('#storyCount').textContent.includes('35') || !$('#storyResults').innerHTML.includes('The Road, the River and the Wilderness')) throw Error('Mark book route');
$('#storyQuery').value='';
location.hash='#study/91000';
await studyNarrative(91000);
if(!app.innerHTML.includes('Matthew 1:1')||!app.innerHTML.includes('#study/91001'))throw Error('Gospel reader or next link');
$('#q0').value='The exile did not end the line of David.';
$('#q0').oninput();
if(!state.notes[91000]?.q0||!cloud.captured)throw Error('Gospel notes contract');
const gospelDocx=buildStudyDocx([{id:91000,lesson:await prepareStudy(91000)}],{from:'2026-11-09',to:'2026-11-15',mode:'journal',includeBible:true,includeCommentary:false,notes:state.notes,progress:state.complete});
const gospelXml = new TextDecoder().decode(gospelDocx);
if(!gospelXml.includes('The exile did not end the line of David.')||!gospelXml.includes('Matthew 1:17')||gospelXml.includes('Matthew 1:18'))throw Error('Gospel Word export');
location.hash='#study/90200';await studyNarrative(90200);if(!app.innerHTML.includes('Spiritual lessons')||!app.innerHTML.includes('The account began with wrongdoing'))throw Error('Narrative reader');
$('#q0').value='I need to act on a responsibility I have avoided.';$('#q0').oninput();if(!state.notes[90200]?.q0||!state.dates[90200]||!cloud.captured)throw Error('Notes contract');
$('#complete').onclick();if(!state.complete.includes(90200))throw Error('Progress');
const l=await prepareStudy(90200);window.storyDocx=buildStudyDocx([{id:90200,lesson:l}],{from:'2026-11-02',to:'2026-11-08',mode:'journal',includeBible:false,includeCommentary:true,notes:state.notes,progress:state.complete});
return {retellings:bibleStories.length,episodes:scriptureScenes.length,coveredVerses:verses,reader:'passed',notes:'passed',wordBytes:window.storyDocx.length};
})()`,context);fs.writeFileSync('/tmp/quiet-time-story-study-qa.docx',context.window.storyDocx);console.log(JSON.stringify(result));})();
