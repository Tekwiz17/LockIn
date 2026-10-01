const api = globalThis.browser || chrome;
const el = id => document.getElementById(id);
let busy = false, latest = null;
const challenge = [...crypto.getRandomValues(new Uint8Array(32))].map(x=>x.toString(16).padStart(2,'0')).join('');
let browserName='Chromium';
const browserReady=LockInBrowser.detect(api).then(name=>{browserName=name;el('autopair').href='lockin://pair?challenge='+challenge+'&browser='+name;});
el('autopair').href = 'lockin://pair?challenge='+challenge+'&browser='+browserName;
el('autopair').onclick = async e => { e.preventDefault();await browserReady;await api.runtime.sendMessage({type:'beginLinkPair',challenge});location.href=el('autopair').href; };
function seconds(value) { const s = Math.max(0,Math.floor(value)); return Math.floor(s/60)+':'+String(s%60).padStart(2,'0'); }
function time(end) { const s = Math.max(0, Math.ceil((end - Date.now()) / 1000)); return Math.floor(s / 60) + ':' + String(s % 60).padStart(2, '0'); }
async function render() {
  if (busy) return;
  try {
    const result = await api.runtime.sendMessage({type: 'status'});
    const s = result.state; latest = s;
    el('autopair').hidden = result.paired;
    el('controls').hidden = !(s?.canPause === true || s?.canStop === true);
    el('pause').hidden = s?.canPause !== true;
    el('stop').hidden = s?.canStop !== true;
    el('pause').disabled = el('stop').disabled = !result.paired;
    el('pause').textContent = s?.sessionMode === 'paused' ? 'Resume' : s?.pauseRequiresChallenge ? 'Pause…' : 'Pause';
    el('stop').textContent = s?.nuclear ? `Emergency Exit (${s.emergencyExitsRemaining ?? 0})` : s?.stopRequiresChallenge ? 'Stop…' : 'Stop';
    el('connection').textContent = result.connected ? '✓ Connected to LockIn' : result.paired ? 'Reconnecting to LockIn…' : 'Not connected';
    el('error').textContent = result.error || '';
    el('pair').hidden = result.paired;
    el('disconnect').hidden = !result.paired || !!s?.sessionID;
    el('retry').hidden = result.connected || !result.paired;
    const active = LockInRules.active(s);
    const names = {focus: 'Focus', shortBreak: 'Short Break', longBreak: 'Long Break', paused: 'Paused', waiting: 'Ready for next phase', idle: 'Ready'};
    el('phase').textContent = ((s && names[s.sessionMode] || 'Ready')+(s?.nuclear ? ' · Nuclear' : '')).toUpperCase();
    if (s?.sessionMode === 'focus' && !active) el('phase').textContent = 'FOCUS ENDED';
    el('timer').textContent = s?.indefinite === true && s?.sessionID ? seconds((s.elapsedSeconds || 0)+(s.sessionMode === 'focus' ? Math.max(0,(Date.now()-(s.serverTime || Date.now()))/1000) : 0))+' elapsed' : s?.sessionMode === 'paused' || s?.sessionMode === 'waiting' ? seconds(s.remainingSeconds || 0) : s?.endDate && s.endDate > Date.now() ? time(s.endDate) : 'Make room for focus.';
    el('summary').textContent = active ? `${s.presetName} · ${s.ruleMode === 'block' ? 'Block' : 'Only Allow'}\n${s.appCount} apps · ${s.domains.length} websites${s.blockAI ? ' · Block AI' : ''}` : 'Everything is unlocked.';
  } catch { el('error').textContent = 'The extension could not start. Reload it from browser extension settings.'; }
}
el('pair').addEventListener('submit', async e => {
  e.preventDefault(); busy = true; el('connect').disabled = true; el('error').textContent = 'Approve the connection in the LockIn desktop app.';
  try { const result = await api.runtime.sendMessage({type: 'pair', code: el('code').value}); if (result.error) throw new Error(result.error); }
  catch (e) { el('error').textContent = e.message; }
  finally { busy = false; el('connect').disabled = false; }
});
el('retry').onclick = async () => { await api.runtime.sendMessage({type: 'retry'}); render(); };
el('disconnect').onclick = async () => { await api.runtime.sendMessage({type: 'disconnect'}); render(); };
render(); setInterval(render, 1000);

async function control(action) {
  busy = true;
  try {
    const result = await api.runtime.sendMessage({type:'control',action});
    if (result.error) throw new Error(result.error);
  } catch (error) { el('error').textContent = error.message; }
  finally { busy = false; render(); }
}
el('pause').onclick = () => control(latest?.sessionMode === 'paused' ? 'resume' : 'pause');
el('stop').onclick = () => { if (confirm(latest?.stopRequiresChallenge ? 'Open the exit check in LockIn? Focus continues until you pass and confirm.' : 'Stop this session and unlock apps and websites?')) control('stop'); };
