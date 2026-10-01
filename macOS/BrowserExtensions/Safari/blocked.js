const api = globalThis.browser || chrome;
const original = location.hash.slice(1);
const safe = /^https?:\/\//i.test(original);
let navigating = false;
async function update() {
  if (navigating) return;
  try {
    const {state, connected} = await api.runtime.sendMessage({type: 'status'});
    if (safe && LockInRules.allowed(original, state)) {
      // Remove an expired network rule before returning; prevents redirect loops after sleep.
      await api.runtime.sendMessage({type: 'expire'}); navigating = true; location.replace(original); return;
    }
    let host = 'This website'; try { host = new URL(original).hostname; } catch {}
    document.getElementById('title').textContent = host + " isn't available.";
    document.getElementById('reason').textContent = state?.blockAI===true && LockInAI.isAI(new URL(original),state.extraAIDomains || []) ? 'Block AI is active for this Focus.' : state?.ruleMode === 'onlyAllow' ? "This website isn't part of this Focus." : 'You blocked this website for this Focus.';
    const seconds = Math.max(0, Math.ceil(((state?.endDate || Date.now()) - Date.now()) / 1000));
    document.getElementById('timer').textContent = state?.indefinite === true ? 'Indefinite Focus' : Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0');
    document.getElementById('status').textContent = connected ? (state?.activityMode === 'focus' ? 'Stay with it. You’re making progress.' : 'Stay with it. Your break is next.') : state?.indefinite === true ? 'Reconnecting. Cached rules expire shortly if LockIn stays offline.' : 'Reconnecting. Your current rules end with this Focus.';
  } catch { document.getElementById('status').textContent = 'Open the extension popup to reconnect.'; }
}
document.getElementById('return').onclick = update;
update(); setInterval(update, 1000);
