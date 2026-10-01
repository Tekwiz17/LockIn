const {test}=require('node:test');const assert=require('node:assert/strict');const vm=require('node:vm');const fs=require('node:fs');const path=require('node:path');
const AI=require('../BrowserExtensions/Shared/ai-policy.js');
const source=fs.readFileSync(path.join(__dirname,'../BrowserExtensions/Shared/ai-hide.js'),'utf8');
function harness(hideAI=true,endDate=Date.now()+60000) {
 const timers=[],redirects=[];let queries=0;
 const location={hostname:'www.google.com',href:'https://www.google.com/search?q=test&udm=14',replace:url=>redirects.push(url)};
 const root={classList:{add(){},toggle(){},remove(){}},append:node=>node.isConnected=true};
 const document={documentElement:root,head:root,hidden:false,createElement:()=>({isConnected:false}),querySelectorAll:()=>[],addEventListener(){}};
 const ctx=vm.createContext({LockInAI:AI,URL,Date,location,document,chrome:{runtime:{getURL:s=>'chrome-extension://unit/'+s,sendMessage:async()=>{queries++;return {hideAI,endDate};},onMessage:{addListener(){}}}},MutationObserver:class {observe(){}disconnect(){}},addEventListener(){},setInterval:(fn,ms)=>timers.push({fn,ms}),setTimeout:fn=>fn()});
 vm.runInContext(source,ctx);return {location,timers,redirects,get queries(){return queries;}};
}
test('AI Mode pushState transition is caught by 100ms local URL watch, without waiting for policy poll',async()=>{
 const h=harness();await new Promise(r=>setImmediate(r));
 const watcher=h.timers.find(t=>t.ms===100);assert.ok(watcher);
 const before=h.queries;watcher.fn();assert.equal(h.queries,before,'unchanged URL does not contact background');
 h.location.href='https://www.google.com/search?q=test&udm=50';watcher.fn();
 assert.equal(h.redirects[0],'chrome-extension://unit/blocked.html#'+h.location.href);
});
test('AI Mode local watch respects disabled or Never Block verdict and expired Focus',async()=>{
 for(const [enabled,deadline] of [[false,Date.now()+60000],[true,Date.now()-1]]) {
  const h=harness(enabled,deadline);await new Promise(r=>setImmediate(r));h.location.href='https://www.google.com/search?q=test&udm=50';h.timers.find(t=>t.ms===100).fn();assert.equal(h.redirects.length,0);
 }
});
test('Web routing preserves query and leaves categories, Web results and AI Mode distinct',()=>{
 const url=AI.webSearchURL('https://www.google.com/search?q=hello+world&start=10&hl=en');
 const parsed=new URL(url);assert.equal(parsed.searchParams.get('udm'),'14');assert.equal(parsed.searchParams.get('q'),'hello world');assert.equal(parsed.searchParams.get('start'),'10');
 for(const input of ['https://google.com/search?q=hi&udm=14','https://google.com/search?q=hi&udm=50','https://google.com/search?q=hi&udm=2','https://google.com/search?q=hi&tbm=isch','https://google.com.attacker.org/search?q=hi','https://google.com/maps?q=hi'])assert.equal(AI.webSearchURL(input),null,input);
});
