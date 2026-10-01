const {test} = require('node:test');
const assert = require('node:assert/strict');
const R = require('../BrowserExtensions/Shared/rules.js');
const now = 1_800_000_000_000;
const base = {protocolVersion:1, installationID:'test-install',revision:8,sessionID:'test-session',sessionMode:'focus',isFocusActive:true,ruleMode:'block',presetName:'Homework',endDate:now+60_000,domains:['youtube.com'],neverBlockDomains:['school.youtube.com'],appCount:2};
test('normalization: URLs, case, port, path, query, trailing dot',()=> {
  for (const [input, expected] of [[' YouTube.COM ','youtube.com'],['https://YouTube.com:443/watch?v=12','youtube.com'],['http://m.youtube.com:8080/path','m.youtube.com'],['example.com.','example.com'],['127.0.0.1:19287','127.0.0.1'],['xn--bcher-kva.de','xn--bcher-kva.de']]) assert.equal(R.normalizeDomain(input), expected, input);
});
test('malformed and unsupported inputs rejected',()=> {
  for (const input of ['', 'https://', 'hello world', 'file:///etc/passwd','https://user:pass@example.com','*.youtube.com','https://example.com:99999','a..com','-a.com','a-.com','example.com\\bad','bücher.de','https://[::1]','http://a.com:0']) assert.equal(R.normalizeDomain(input),null,input);
});
test('boundary matching and Never Block precedence',()=> {
  for (const url of ['https://youtube.com','https://m.youtube.com/a','http://YOUTUBE.COM:8080/','https://youtube.com./']) assert.equal(R.allowed(url,base,now),false,url);
  for (const url of ['https://notyoutube.com','https://youtube.com.attacker.org','https://school.youtube.com','https://x.school.youtube.com','chrome://settings','file:///tmp/a']) assert.equal(R.allowed(url,base,now),true,url);
});
test('Only Allow and independent website policy',()=> {
  const s={...base,ruleMode:'onlyAllow',domains:['docs.google.com'],neverBlockDomains:['school.example.com']};
  assert.equal(R.allowed('https://docs.google.com/a',s,now),true);
  assert.equal(R.allowed('https://sub.docs.google.com',s,now),true);
  assert.equal(R.allowed('https://school.example.com',s,now),true);
  assert.equal(R.allowed('https://youtube.com',s,now),false);
  assert.equal(R.allowed('https://google.com',s,now),false);
});
test('break, pause, expiry and offline fail-open deadline',()=> {
  for(const s of [{...base,isFocusActive:false},{...base,endDate:now},{...base,endDate:now-1},null]) {
    assert.equal(R.allowed('https://youtube.com',s,now),true);
    assert.deepEqual(R.netRules(s,'chrome-extension://test/',now),[]);
  }
  assert.equal(R.allowed('https://youtube.com',base,now+59999),false);
  assert.equal(R.allowed('https://youtube.com',base,now+60000),true);
});
test('serialization, protocol validation, stale revision rejection, new installation',()=> {
  const copy=JSON.parse(JSON.stringify(base)); assert.equal(R.valid(copy),true);
  assert.equal(R.accepts(base,{...base,revision:7}),false);
  assert.equal(R.accepts(base,{...base,revision:8}),true);
  assert.equal(R.accepts(base,{...base,revision:9}),true);
  assert.equal(R.accepts(base,{...base,installationID:'new',revision:1}),true);
  for(const bad of [{...base,protocolVersion:2},{...base,domains:['bad domain']},{...base,endDate:'tomorrow'},{...base,ruleMode:'oops'}]) assert.equal(R.valid(bad),false);
});
function networkAllows(url,s) {
 const rules=R.netRules(s,'chrome-extension://test/',now).filter(r=> {
   if(r.condition.requestDomains && !r.condition.requestDomains.some(d=>R.matches(new URL(url).hostname.replace(/\.$/,''),d)))return false;
   if(r.condition.regexFilter) return new RegExp(r.condition.regexFilter,r.condition.isUrlFilterCaseSensitive?'':'i').test(url);
   const domain=r.condition.urlFilter.slice(2,-1);return R.matches(new URL(url).hostname,domain);
 }).sort((a,b)=>b.priority-a.priority);
 return !rules.length || rules[0].action.type==='allow';
}
test('declarative network policy agrees with shared policy',()=> {
 for(const mode of ['block','onlyAllow']) for(const domains of [[],['youtube.com'],['docs.google.com','example.com']]) {
  const s={...base,ruleMode:mode,domains};
  for(const h of ['youtube.com','www.youtube.com','school.youtube.com','x.school.youtube.com','notyoutube.com','youtube.com.bad.org','docs.google.com','example.com','www.example.com','other.org'])
   for(const scheme of ['http','https']) for(const suffix of ['/','/path?x=1',':8080/path','.']) {
    const url=scheme+'://'+h+suffix;
    assert.equal(networkAllows(url,s),R.allowed(url,s,now),JSON.stringify({mode,domains,url}));
   }
 }
});
test('DNR IDs unique and redirect preserves complete original address',()=> {
 const rules=R.netRules(base,'chrome-extension://test/',now);
 assert.equal(new Set(rules.map(r=>r.id)).size,rules.length);
 const block=rules.find(r=>r.action.type==='redirect');
 assert.equal(block.action.redirect.regexSubstitution,'chrome-extension://test/blocked.html#\\0');
});

test('indefinite Focus uses renewable finite lease, never an unbounded cached lock',()=>{
  const state={...base,indefinite:true,activityMode:'focus',endDate:now+90000};
  assert.equal(R.valid(state),true);
  assert.equal(R.allowed('https://youtube.com',state,now+89999),false);
  assert.equal(R.allowed('https://youtube.com',state,now+90000),true);
  assert.equal(R.allowed('https://youtube.com',{...state,endDate:null},now),true);
  assert.equal(R.valid({...state,indefinite:'yes'}),false);
});
test('live rule edits apply both modes and removals without changing Focus deadline',()=>{
  const state={...base,revision:base.revision+1,ruleMode:'onlyAllow',domains:['youtube.com'],neverBlockDomains:[]};
  assert.equal(R.accepts(base,state),true);
  assert.equal(R.allowed('https://youtube.com',state,now),true);
  assert.equal(R.allowed('https://example.com',state,now),false);
  assert.equal(R.allowed('https://example.com',{...state,domains:['youtube.com','example.com']},now),true);
  assert.equal(R.allowed('https://youtube.com',{...state,ruleMode:'block',domains:[]},now),true);
  assert.equal(state.endDate,base.endDate);
});

test('Block AI overrides Only Allow but honors Never Block, inactive and expiry',()=>{
 for(const mode of ['block','onlyAllow']) {
  const state={...base,ruleMode:mode,domains:['chatgpt.com','google.com'],blockAI:true};
  assert.equal(R.allowed('https://chatgpt.com',state,now),false);
  assert.equal(R.allowed('https://chatgpt.com',{...state,neverBlockDomains:['chatgpt.com']},now),true);
  assert.equal(R.allowed('https://chatgpt.com',{...state,isFocusActive:false},now),true);
  assert.equal(R.allowed('https://chatgpt.com',state,state.endDate),true);
 }
 assert.equal(R.allowed('https://chatgpt.com',{...base,blockAI:false},now),true);
});
test('AI domains, added sites and embedded AI paths agree with DNR',()=>{
 const AI=require('../BrowserExtensions/Shared/ai-policy.js');
 const blocked=[...AI.domains.map(d=>'https://'+d+'/'), 'https://sub.chatgpt.com/', 'https://x.com/i/grok','https://x.com/i/grok/chat/123','https://huggingface.co/chat/','https://bing.com/copilot?q=test','https://www.google.com/search?q=test&udm=50','https://google.co.uk/search?udm=50&q=test','https://google.com/search?q=test&udm=%35%30','https://google.com/search?udm=14&udm=50','https://my-ai.example.com'];
 const allowed=['https://google.com/search?q=ai','https://google.com/search?q=test&udm=14','https://google.com/search?udm=500','https://x.com/home','https://x.com/i/groking','https://huggingface.co/docs','https://bing.com/search?q=test','https://bing.com/chatty','https://chatgpt.com.attacker.org','https://notchatgpt.com','https://my-ai.example.com.attacker.org'];
 for(const mode of ['block','onlyAllow']) {
  const state={...base,ruleMode:mode,domains:mode==='onlyAllow'?['google.com','google.co.uk','x.com','huggingface.co','bing.com','chatgpt.com','notchatgpt.com','attacker.org']:[],blockAI:true,extraAIDomains:['my-ai.example.com']};
  for(const url of blocked) {assert.equal(R.allowed(url,state,now),false,url);assert.equal(networkAllows(url,state),false,url);}
  for(const url of allowed) {assert.equal(R.allowed(url,state,now),true,url);assert.equal(networkAllows(url,state),true,url);}
  for(const domain of ['chatgpt.com','google.com','my-ai.example.com']) {
   const exempt={...state,neverBlockDomains:[domain]};const url=domain==='google.com'?'https://google.com/search?udm=50':'https://'+domain;
   assert.equal(R.allowed(url,exempt,now),true);assert.equal(networkAllows(url,exempt),true);
  }
 }
});
test('AI wire fields remain compatible with old extensions and reject malformed configuration',()=>{
 assert.equal(R.valid(base),true);
 assert.equal(R.valid({...base,blockAI:true,extraAIDomains:['example.com']}),true);
 for(const state of [{...base,blockAI:'yes'},{...base,extraAIDomains:['bad domain']},{...base,extraAIDomains:'example.com'},{...base,extraAIDomains:Array(401).fill('example.com')}])assert.equal(R.valid(state),false);
});
