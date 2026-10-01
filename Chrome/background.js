/* Shared by Chromium's MV3 worker and Safari's nonpersistent background page. */
if (typeof importScripts === 'function') importScripts('ai-policy.js','rules.js');
const api = globalThis.browser || globalThis.chrome;
const R = globalThis.LockInRules;
const endpoint = 'http://127.0.0.1:19287';
let state = null, token = null, connected = false, lastError = '', policyWarning = '', initialized = false;
let currentRequest = null, generation = 0, retryTimer = null, expirationTimer = null;
let serial = Promise.resolve();
const enqueue = job => { const result = serial.then(job); serial = result.catch(e => { lastError = e.message; }); return result; };
let pairTimer = null;
const ready = (async () => {
  const saved = await api.storage.local.get(['state', 'token']);
  state = R.valid(saved.state) ? saved.state : null; token = saved.token || null;
  await installPolicy(); initialized = true;
})();
async function installPolicy() {
  const old = await api.declarativeNetRequest.getDynamicRules();
  let rules = R.netRules(state, api.runtime.getURL(''));
  policyWarning='';
  try {
    if(api.declarativeNetRequest.isRegexSupported) {
      const supported=[];let unsafeAllow=false;
      for(const rule of rules) {
        if(!rule.condition.regexFilter){supported.push(rule);continue;}
        const check=await api.declarativeNetRequest.isRegexSupported({regex:rule.condition.regexFilter,isCaseSensitive:rule.condition.isUrlFilterCaseSensitive===true,requireCapturing:rule.action.type==='redirect'});
        if(check.isSupported)supported.push(rule);
        else {
          if(rule.action.type==='allow')unsafeAllow=true;
          policyWarning='Some network rules are unsupported; page guards remain active.';
        }
      }
      // Never keep a catch-all block after dropping an explicit allowance.
      rules=unsafeAllow?[]:supported;
    }
    await api.declarativeNetRequest.updateDynamicRules({removeRuleIds:old.map(r=>r.id),addRules:rules});
  } catch(error) {
    // A rejected rule must not stop state sync or Google AI hiding.
    policyWarning='Network rules unavailable; page guards remain active. '+error.message;
    await api.declarativeNetRequest.updateDynamicRules({removeRuleIds:old.map(r=>r.id),addRules:[]});
  }
  clearTimeout(expirationTimer);
  await api.alarms.clear('expire');
  if (R.active(state)) {
    api.alarms.create('expire', {when: state.endDate});
    expirationTimer = setTimeout(() => enqueue(installPolicy), Math.min(2147483647, Math.max(0, state.endDate - Date.now() + 30)));
  }
  await refreshTabs();
}
function googleWebTarget(url) {
  if(!R.active(state) || state?.blockAI!==true || !R.allowed(url,state))return null;
  let host;try {host=new URL(url).hostname.toLowerCase().replace(/\.$/,'');}catch{return null;}
  if(state.neverBlockDomains.some(d=>R.matches(host,d)))return null;
  return globalThis.LockInAI?.webSearchURL(url) || null;
}
async function refreshTabs() {
  const tabs = await api.tabs.query({});
  for (const tab of tabs) {
    if (!tab.id || !tab.url) continue;
    if (api.tabs.sendMessage) await api.tabs.sendMessage(tab.id,{type:'policyChanged'}).catch(()=>{});
    if (/^https?:/i.test(tab.url) && !R.allowed(tab.url, state)) {
      await api.tabs.update(tab.id, {url: api.runtime.getURL('blocked.html') + '#' + tab.url}).catch(() => {});
    } else if (googleWebTarget(tab.url)) {
      await api.tabs.update(tab.id,{url:googleWebTarget(tab.url)}).catch(()=>{});
    } else if (tab.url.startsWith(api.runtime.getURL('blocked.html') + '#')) {
      const original = tab.url.slice(tab.url.indexOf('#') + 1);
      if (/^https?:\/\//i.test(original) && R.allowed(original, state)) await api.tabs.update(tab.id, {url: original}).catch(() => {});
    }
  }
}
async function request(path, options = {}) {
  const abort = new AbortController(); currentRequest = abort;
  const timeout = setTimeout(() => abort.abort(), 25000);
  try {
    const response = await fetch(endpoint + path, {...options, signal: abort.signal, cache: 'no-store'});
    let data; try { data = await response.json(); } catch { throw new Error('LockIn returned an unreadable response.'); }
    if (!response.ok) {
      if (response.status === 401) { token = null; await api.storage.local.remove('token'); }
      throw new Error(data.error || 'Open LockIn and try connecting again.');
    }
    return data;
  } finally { clearTimeout(timeout); if (currentRequest === abort) currentRequest = null; }
}
async function connectLoop(epoch) {
  await ready;
  if (!token || epoch !== generation) return;
  try {
    const next = await request('/state?revision=' + (connected ? (state?.revision ?? -1) : -1) + '&installation=' + encodeURIComponent(state?.installationID || ''), {headers: {Authorization: 'Bearer ' + token}});
    if (epoch !== generation) return;
    if (!R.accepts(state, next)) throw new Error('Waiting for a current LockIn state.');
    connected = true; lastError = '';
    await enqueue(async () => {
      if (epoch !== generation || !R.accepts(state,next)) return;
      const changed = !state || next.installationID !== state.installationID || next.revision !== state.revision || next.isFocusActive !== state.isFocusActive;
      state = next; await api.storage.local.set({state});
      if (changed) await installPolicy();
    });
    if (epoch === generation) retryTimer = setTimeout(() => connectLoop(epoch), 60);
  } catch (e) {
    if (epoch !== generation) return;
    connected = false; lastError = e.message === 'Failed to fetch' ? 'LockIn is unavailable. Open the Mac app; we’ll keep trying.' : e.message;
    if (!R.active(state)) await enqueue(installPolicy);
    retryTimer = setTimeout(() => connectLoop(epoch), 5000);
  }
}
async function acceptPairToken(result) {
  if (!/^[a-f0-9]{64}$/i.test(result.token)) throw new Error('Invalid connection credential.');
  generation++; currentRequest?.abort(); clearTimeout(retryTimer);
  token = result.token; state = null; connected = false;
  await api.storage.local.set({token}); await api.storage.local.remove(['state', 'linkPair']);
  await enqueue(installPolicy); restart();
}
async function claimLinkPair() {
  await ready;
  const saved = await api.storage.local.get('linkPair');
  const pending = saved.linkPair;
  if (!pending || Date.now() >= pending.expires) { if(pending) lastError='Automatic pairing expired. Try again or use the backup code.'; await api.storage.local.remove('linkPair'); return; }
  try {
    const response = await fetch(endpoint + '/pair-link', {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({challenge:pending.challenge}),signal:AbortSignal.timeout(5000)});
    const result = await response.json();
    if (response.ok && result.token) { const current=await api.storage.local.get('linkPair'); if(current.linkPair?.challenge===pending.challenge) await acceptPairToken(result); return; }
    if (!response.ok) lastError = result.error || 'Use the backup connection code.';
  } catch { lastError = 'Open LockIn and approve pairing, or use the backup code.'; }
  clearTimeout(pairTimer); pairTimer = setTimeout(claimLinkPair, 2000);
}
function restart() { generation++; clearTimeout(retryTimer); currentRequest?.abort(); connectLoop(generation); }
api.alarms.onAlarm.addListener(alarm => {
  if (alarm.name === 'expire') ready.then(() => enqueue(installPolicy));
  if (alarm.name === 'recover') { if (!currentRequest) restart(); claimLinkPair(); }
});
api.alarms.create('recover', {periodInMinutes: 1});
api.runtime.onStartup.addListener(restart);
api.runtime.onInstalled.addListener(restart);
api.tabs.onUpdated.addListener((id, change, tab) => {
  if (!change.url && change.status !== 'loading') return;
  ready.then(() => {
    if(api.tabs.sendMessage)api.tabs.sendMessage(id,{type:'policyChanged'}).catch(()=>{});
    if (tab.url && /^https?:/i.test(tab.url) && !R.allowed(tab.url, state)) api.tabs.update(id, {url: api.runtime.getURL('blocked.html') + '#' + tab.url}).catch(() => {});
  });
});
api.runtime.onMessage.addListener((message, sender, respond) => {
  // Only extension pages can pair, disconnect, or request settings. Content scripts get a boolean only.
  const extensionPage = sender.url?.startsWith(api.runtime.getURL(''));
  (async () => {
    await ready;
    if (message.type === 'check') {
      const url = sender.tab?.url || '';
      let exempt = false;
      try { const host = new URL(url).hostname.toLowerCase().replace(/\.$/,''); exempt = state?.neverBlockDomains.some(d=>R.matches(host,d))===true; } catch {}
      return {allowed: R.allowed(url, state), endDate: state?.endDate || null, hideAI: R.active(state) && state?.blockAI===true && !exempt};
    }
    if (!extensionPage) throw new Error('Extension page required.');
    if (message.type === 'status') return {state, connected, paired: !!token, error: lastError || policyWarning};
    if (message.type === 'beginLinkPair') {
      if (!/^[a-f0-9]{64}$/i.test(message.challenge)) throw new Error('Invalid pairing request.');
      await api.storage.local.set({linkPair:{challenge:message.challenge,expires:Date.now()+120000}});
      claimLinkPair(); return {ok:true};
    }
    if (message.type === 'control') {
      if (!token || !state?.sessionID) throw new Error('Reconnect to LockIn first.');
      if (!['pause','resume','stop'].includes(message.action)) throw new Error('Unknown control.');
      const epoch = generation;
      const response = await fetch(endpoint+'/control',{method:'POST',headers:{Authorization:'Bearer '+token,'Content-Type':'application/json'},body:JSON.stringify({action:message.action,sessionID:state.sessionID}),signal:AbortSignal.timeout(5000)});
      const next = await response.json();
      if (!response.ok) throw new Error(next.error || 'Control unavailable.');
      if (epoch === generation) await enqueue(async()=>{if(epoch!==generation || !R.accepts(state,next))return;state=next;await api.storage.local.set({state});await installPolicy();});
      connected = true; lastError = ''; return {ok:true};
    }
    if (message.type === 'pair') {
      generation++; currentRequest?.abort(); clearTimeout(retryTimer);
      const result = await request('/pair', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({name: api.runtime.getManifest().background.service_worker ? 'Chrome' : 'Safari', code: String(message.code).trim()})});
      await acceptPairToken(result); return {ok:true};
    }
    if (message.type === 'disconnect') {
      if (R.active(state)) throw new Error('End Focus through LockIn before disconnecting.');
      generation++; currentRequest?.abort(); clearTimeout(retryTimer); token = null; state = null; connected = false; lastError = '';
      clearTimeout(pairTimer); await api.storage.local.remove(['state', 'token', 'linkPair']); await enqueue(installPolicy); return {ok: true};
    }
    if (message.type === 'retry') { restart(); return {ok: true}; }
    if (message.type === 'expire') { await enqueue(installPolicy); return {ok: true}; }
    throw new Error('Unknown request.');
  })().then(respond, e => { lastError=e.message; respond({error:e.message}); });
  return true;
});
ready.then(()=>{restart();claimLinkPair();}).catch(e => { lastError = 'Website rules could not be installed: ' + e.message; });
