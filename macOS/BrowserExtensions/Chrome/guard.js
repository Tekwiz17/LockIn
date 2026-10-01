/* Catches restored/back-forward cached documents; no website content is collected. */
(() => {
  const api = globalThis.browser || chrome;
  async function check() {
    try {
      const verdict = await api.runtime.sendMessage({type: 'check'});
      if (verdict.allowed === false) location.replace(api.runtime.getURL('blocked.html') + '#' + location.href);
    } catch {}
  }
  check(); addEventListener('pageshow', check); addEventListener('popstate', check);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) check(); });
})();
