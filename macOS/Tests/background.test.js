const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const R = require('../BrowserExtensions/Shared/rules.js');
const base={protocolVersion:1,installationID:'mac-1',revision:10,sessionID:'s',sessionMode:'focus',isFocusActive:true,ruleMode:'block',presetName:'Homework',endDate:Date.now()+600000,domains:['youtube.com'],neverBlockDomains:['school.youtube.com'],appCount:1};
function harness(saved={},tabs=[]) {
 const storage=structuredClone(saved), updates=[], timers=[], listeners={};let rules=[], fetcher=async()=>{throw new Error('Failed to fetch')};
 const event=name=>({addListener:fn=>listeners[name]=fn});
 const api={
  runtime:{getURL:s=>'chrome-extension://unit/'+s,getManifest:()=>({background:{service_worker:'background.js'}}),onMessage:event('message'),onStartup:event('startup'),onInstalled:event('installed')},
  storage:{local:{get:async()=>structuredClone(storage),set:async data=>Object.assign(storage,structuredClone(data)),remove:async keys=>{for(const k of Array.isArray(keys)?keys:[keys])delete storage[k];}}},
  declarativeNetRequest:{getDynamicRules:async()=>rules,updateDynamicRules:async change=>{rules=rules.filter(r=>!change.removeRuleIds.includes(r.id)).concat(change.addRules);}},
  tabs:{query:async()=>tabs,update:async(id,update)=>{updates.push({id,...update});const tab=tabs.find(t=>t.id===id);if(tab)Object.assign(tab,update);},onUpdated:event('tab')},
  alarms:{clear:async()=>true,create:()=>{},onAlarm:event('alarm')}
 };
 const ctx=vm.createContext({chrome:api,LockInRules:R,LockInAI:require('../BrowserExtensions/Shared/ai-policy.js'),console,URL,AbortController,AbortSignal,setTimeout:(fn,ms)=>{timers.push({fn,ms});return timers.length;},clearTimeout:()=>{},fetch:(...args)=>fetcher(...args)});
 vm.runInContext(fs.readFileSync(path.join(__dirname,'../BrowserExtensions/Shared/background.js'),'utf8'),ctx);
 return {api,ctx,storage,updates,timers,listeners,get rules(){return rules},setFetch:fn=>fetcher=fn,eval:s=>vm.runInContext(s,ctx),message:async(msg,sender={url:'chrome-extension://unit/popup.html'})=>new Promise(resolve=>listeners.message(msg,sender,resolve))};
}
const flush=()=>new Promise(r=>setImmediate(r));
test('worker restart restores cached Focus and redirects existing blocked tabs',async()=>{
 const h=harness({state:base,token:'t'},[{id:1,url:'https://youtube.com/watch'},{id:2,url:'https://school.youtube.com'}]);
 await h.eval('ready'); await flush();
 assert.equal(h.rules.length,2);assert.equal(h.updates.length,1);assert.match(h.updates[0].url,/blocked.html#https:\/\/youtube.com/);
 const status=await h.message({type:'status'});assert.equal(status.paired,true);assert.equal(status.connected,false);
 assert.equal(h.rules.length,2,'offline request retains policy');
});
test('expired cache clears network rules and restores original website',async()=>{
 const h=harness({state:{...base,endDate:Date.now()-1}},[{id:1,url:'chrome-extension://unit/blocked.html#https://youtube.com/watch'}]);
 await h.eval('ready');assert.equal(h.rules.length,0);assert.equal(h.updates[0].url,'https://youtube.com/watch');
});
test('authoritative break removes policy and unlocks tabs',async()=>{
 const h=harness({state:base,token:'t'},[{id:1,url:'chrome-extension://unit/blocked.html#https://youtube.com'}]);
 await h.eval('ready');await flush();
 h.setFetch(async()=>({ok:true,json:async()=>({...base,revision:11,isFocusActive:false,sessionMode:'shortBreak'})}));
 await h.eval('connectLoop(generation)');
 assert.equal(h.rules.length,0);assert.equal(h.updates.at(-1).url,'https://youtube.com');assert.equal(h.storage.state.revision,11);
});
test('stale response cannot replace current rules',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');await flush();
 h.setFetch(async()=>({ok:true,json:async()=>({...base,revision:9,isFocusActive:false})}));
 await h.eval('connectLoop(generation)');assert.equal(h.storage.state.revision,10);assert.equal(h.rules.length,2);
});
test('page scripts cannot read rules, pair, or disconnect',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');
 const sender={url:'https://youtube.com',tab:{id:1,url:'https://youtube.com'}};
 for(const type of ['status','pair','disconnect','control','beginLinkPair'])assert.match((await h.message({type},sender)).error,/Extension page required/);
 const verdict=await h.message({type:'check'},sender);assert.equal(verdict.allowed,false);assert.equal(verdict.domains,undefined);
});
test('explicit disconnect clears credentials and rules',async()=>{
 const h=harness({state:{...base,isFocusActive:false},token:'t'});await h.eval('ready');await h.message({type:'disconnect'});
 assert.equal(h.storage.token,undefined);assert.equal(h.storage.state,undefined);assert.equal(h.rules.length,0);
});
test('Swift idle payload omits nil endDate and remains valid',async()=>{
 const idle={...base,revision:11,isFocusActive:false,sessionMode:'idle'};delete idle.endDate;delete idle.sessionID;
 assert.equal(R.valid(idle),true);
 const h=harness({state:base,token:'t'});await h.eval('ready');await flush();
 h.setFetch(async()=>({ok:true,json:async()=>idle}));await h.eval('connectLoop(generation)');assert.equal(h.rules.length,0);
});
test('expiry alarm removes rules after a worker has been suspended',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');
 h.eval('state.endDate = Date.now()-1');h.listeners.alarm({name:'expire'});await flush();await h.eval('serial');assert.equal(h.rules.length,0);
});

test('popup control sends authenticated session-scoped stop and installs returned unlock',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');await flush();h.eval('connected=true');
 let call;
 h.setFetch(async(url,options)=>{call={url,options};return {ok:true,json:async()=>({...base,revision:11,sessionMode:'idle',isFocusActive:false,sessionID:null})};});
 const result=await h.message({type:'control',action:'stop'});
 assert.equal(result.ok,true);assert.match(call.url,/\/control$/);assert.equal(call.options.headers.Authorization,'Bearer t');
 assert.deepEqual(JSON.parse(call.options.body),{action:'stop',sessionID:'s'});assert.equal(h.rules.length,0);
});
test('popup cannot control offline or bypass a Nuclear rejection',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');await flush();
 assert.match((await h.message({type:'control',action:'stop'})).error,/Failed to fetch/);
 h.eval('connected=true');h.setFetch(async()=>({ok:false,json:async()=>({error:'Nuclear Mode locks these controls.'})}));
 assert.match((await h.message({type:'control',action:'pause'})).error,/Nuclear/);assert.equal(h.storage.state.revision,10);
});
test('approved automatic pairing claims token and clears one-time challenge',async()=>{
 const challenge='a'.repeat(64);const credential='b'.repeat(64);
 const h=harness({linkPair:{challenge,expires:Date.now()+120000}});await h.eval('ready');await flush();
 h.setFetch(async(url,options)=>{
  if(url.endsWith('/pair-link')) {assert.deepEqual(JSON.parse(options.body),{challenge});return {ok:true,json:async()=>({token:credential})};}
  throw new Error('Failed to fetch');
 });
 await h.eval('claimLinkPair()');assert.equal(h.storage.token,credential);assert.equal(h.storage.linkPair,undefined);
});
test('expired link pairing never claims or stores credentials',async()=>{
 const h=harness({linkPair:{challenge:'a'.repeat(64),expires:Date.now()-1}});await h.eval('ready');await flush();
 let calls=0;h.setFetch(async()=>{calls++;throw new Error('unexpected fetch');});await h.eval('claimLinkPair()');
 assert.equal(calls,0);assert.equal(h.storage.token,undefined);assert.equal(h.storage.linkPair,undefined);
});

test('Google AI hiding verdict follows Focus, toggle, expiry and Never Block',async()=>{
 for(const [patch,expected] of [[{blockAI:true},true],[{blockAI:false},false],[{blockAI:true,isFocusActive:false},false],[{blockAI:true,endDate:Date.now()-1},false],[{blockAI:true,neverBlockDomains:['google.com']},false]]) {
  const h=harness({state:{...base,...patch}});await h.eval('ready');
  const result=await h.message({type:'check'},{url:'https://www.google.com/search?q=test',tab:{id:1,url:'https://www.google.com/search?q=test'}});
  assert.equal(result.hideAI,expected);assert.equal(result.domains,undefined);assert.equal(result.token,undefined);
 }
});

test('active Focus cannot be unlocked through extension Disconnect',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');
 assert.match((await h.message({type:'disconnect'})).error,/End Focus/);
 assert.equal(h.storage.token,'t');assert.equal(h.storage.state.sessionID,base.sessionID);assert.equal(h.rules.length,2);
});

test('unsupported regex is excluded without disabling Google AI page hiding',async()=>{
 const h=harness({state:{...base,blockAI:true}});
 let checks=0;
 h.api.declarativeNetRequest.isRegexSupported=async ({regex})=>{checks++;return {isSupported:!regex.includes('/i/grok')};};
 await h.eval('ready');assert.ok(checks>0);
 assert.equal(h.rules.some(r=>r.condition.regexFilter?.includes('/i/grok')),false);
 const result=await h.message({type:'check'},{url:'https://google.com/search?q=test',tab:{url:'https://google.com/search?q=test'}});
 assert.equal(result.hideAI,true);
 assert.match((await h.message({type:'status'})).error,/unsupported/);
});
test('rejected network rule does not break sync initialization or AI hiding',async()=>{
 const h=harness({state:{...base,blockAI:true}});
 const update=h.api.declarativeNetRequest.updateDynamicRules;
 h.api.declarativeNetRequest.updateDynamicRules=async change=>{if(change.addRules.length)throw new Error('regexFilter unsupported');return update(change);};
 await h.eval('ready');assert.equal(h.rules.length,0);
 const result=await h.message({type:'check'},{url:'https://google.com/search?q=test',tab:{url:'https://google.com/search?q=test'}});
 assert.equal(result.hideAI,true);assert.match((await h.message({type:'status'})).error,/Network rules unavailable/);
});
test('unsupported Never Block rule cannot leave a catch-all Only Allow block installed',async()=>{
 const h=harness({state:{...base,ruleMode:'onlyAllow'}});
 h.api.declarativeNetRequest.isRegexSupported=async()=>({isSupported:false});
 await h.eval('ready');assert.equal(h.rules.length,0);
 const result=await h.message({type:'check'},{url:'https://school.youtube.com',tab:{url:'https://school.youtube.com'}});
 assert.equal(result.allowed,true);
});

test('reconnect asks for immediate state instead of entering a twenty-second cached-revision wait',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');await flush();let requested;
 h.setFetch(async url=>{requested=new URL(url);return {ok:true,json:async()=>base};});
 await h.eval('connectLoop(generation)');assert.equal(requested.searchParams.get('revision'),'-1');
 assert.equal((await h.message({type:'status'})).connected,true);
});
test('authenticated control can reconnect immediately while state polling is pending',async()=>{
 const h=harness({state:base,token:'t'});await h.eval('ready');await flush();
 h.setFetch(async()=>({ok:true,json:async()=>({...base,revision:11,isFocusActive:false,sessionMode:'paused'})}));
 const result=await h.message({type:'control',action:'pause'});assert.equal(result.ok,true);
 assert.equal((await h.message({type:'status'})).connected,true);
});
test('enabling Block AI switches ordinary Google tabs to Web results while respecting Never Block',async()=>{
 for(const exempt of [false,true]) {
  const h=harness({state:{...base,blockAI:true,neverBlockDomains:exempt?['google.com']:[]} },[{id:1,url:'https://www.google.com/search?q=hello'}]);
  await h.eval('ready');assert.equal(h.updates.length,exempt?0:1);
  if(!exempt)assert.equal(new URL(h.updates[0].url).searchParams.get('udm'),'14');
 }
});
