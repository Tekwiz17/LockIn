const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
let JSDOM;try {({JSDOM}=require('jsdom'));}catch {}
const source=name=>fs.readFileSync(path.join(__dirname,'../BrowserExtensions/Shared/',name),'utf8');
const wait=()=>new Promise(resolve=>setTimeout(resolve,130));
function fixture(html,url='https://www.google.com/search?q=test') {
 const dom=new JSDOM(html,{url,runScripts:'outside-only',pretendToBeVisual:true});
 const w=dom.window;let flag=true, listener;
 w.chrome={runtime:{sendMessage:async()=>({hideAI:flag}),onMessage:{addListener:fn=>listener=fn}}};
 w.setInterval=()=>0;
 w.eval(source('ai-policy.js'));w.eval(source('ai-hide.js'));
 return {w,dom,change:async value=>{flag=value;listener?.({type:'policyChanged'});await wait();}};
}
const domTest=(name,fn)=>test(name,{skip:!JSDOM},fn);
domTest('detected AI overview and exact AI Mode link hide while web results remain visible',async()=>{
 const f=fixture('<main id="main"><section data-attrid="AIOverview" id="ai"><h2>AI Overview</h2><p>Answer</p></section><div id="rso"><a id="result" href="https://example.com">Normal result</a></div><a id="mode" href="/search?udm=50">AI Mode</a><a id="web" href="/search?udm=14">Web</a><a id="other" href="/search?udm=500">Other</a></main>');
 try {await wait();for(const id of ['ai','mode'])assert.equal(f.w.getComputedStyle(f.w.document.getElementById(id)).display,'none',id);
 for(const id of ['main','rso','result','web','other'])assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById(id)).display,'none',id);
 await f.change(false);for(const id of ['ai','mode'])assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById(id)).display,'none',id);
 await f.change(true);assert.equal(f.w.getComputedStyle(f.w.document.getElementById('ai')).display,'none');
 }finally {f.dom.window.close();}
});
domTest('late injected AI panel hides; ordinary result mentioning AI Overview does not',async()=>{
 const f=fixture('<div id="search"><div id="rso"><div data-hveid="1" id="normal"><a href="https://example.com"><h2>AI Overview</h2></a></div></div></div>');
 try {await wait();f.w.document.getElementById('search').insertAdjacentHTML('afterbegin','<section data-hveid="2" id="late"><h2>AI Overview</h2><p>Summary</p></section>');await wait();
 assert.equal(f.w.getComputedStyle(f.w.document.getElementById('late')).display,'none');
 assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById('normal')).display,'none');
 }finally {f.dom.window.close();}
});
domTest('result root and containers holding normal results never get hidden',async()=>{
 const f=fixture('<main role="main" data-attrid="AIOverview"><div data-hveid="3" id="wrapper"><h2>AI Overview</h2><div id="rso">Normal results</div></div></main>');
 try {await wait();for(const node of f.w.document.querySelectorAll('main,#wrapper,#rso')) {assert.equal(node.hasAttribute('data-lockin-ai-hidden'),false);assert.notEqual(f.w.getComputedStyle(node).display,'none');}}
 finally {f.dom.window.close();}
});
domTest('overview hiding does not run on lookalike Google domains',async()=>{
 const f=fixture('<div data-attrid="AIOverview" id="ai">Summary</div>','https://www.google.com.attacker.org/search?q=test');
 try {await wait();assert.equal(f.w.document.documentElement.classList.contains('lockin-hide-ai'),false);assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById('ai')).display,'none');}finally {f.dom.window.close();}
});
domTest('Google reused panel becomes visible when it no longer contains AI UI',async()=>{
 const f=fixture('<section data-hveid="4" id="panel"><h2>AI Overview</h2><p>Summary</p></section>');
 try {await wait();const panel=f.w.document.getElementById('panel');assert.equal(f.w.getComputedStyle(panel).display,'none');panel.innerHTML='<h2>Ordinary web results</h2><p>A result</p>';await wait();assert.notEqual(f.w.getComputedStyle(panel).display,'none');}
 finally {f.dom.window.close();}
});

domTest('span headings and current AI module markers hide without hiding normal links',async()=>{
 const f=fixture('<main><div data-hveid="8" id="span-panel"><span>AI Overview</span><p>Summary</p></div><div data-container-id="ai-overview" id="module">Summary</div><div id="m-x-content">Generated summary</div><div data-hveid="9" id="normal"><a href="https://example.com"><span>AI Overview</span></a></div></main>');
 try {await wait();for(const id of ['span-panel','module','m-x-content'])assert.equal(f.w.getComputedStyle(f.w.document.getElementById(id)).display,'none',id);
 assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById('normal')).display,'none');}
 finally {f.dom.window.close();}
});
domTest('collapsed, generating and plain-div overview variants hide before expansion',async()=>{
 const f=fixture('<main><div id="rso"><div id="collapsed" class="YzCcne">Collapsed answer</div><div data-hveid="20" id="generating"><div data-async-type="folsrch">Generating</div></div><div data-mcpr id="label"><div>AI Overview</div><p>Collapsed content</p></div><div id="normal">Normal result</div></div></main>');
 try {await wait();for(const id of ['collapsed','generating','label'])assert.equal(f.w.getComputedStyle(f.w.document.getElementById(id)).display,'none',id);
 assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById('normal')).display,'none');
 await f.change(false);assert.notEqual(f.w.getComputedStyle(f.w.document.getElementById('collapsed')).display,'none');}
 finally {f.dom.window.close();}
});
domTest('existing node becoming an overview via attributes hides without expansion',async()=>{
 const f=fixture('<div id="panel">Collapsed answer</div>');
 try {await wait();const node=f.w.document.getElementById('panel');node.className='YzCcne';await wait();assert.equal(f.w.getComputedStyle(node).display,'none');node.className='normal';await wait();assert.notEqual(f.w.getComputedStyle(node).display,'none');}
 finally {f.dom.window.close();}

});
