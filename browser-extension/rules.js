/* Canonical website policy: safety > Never Block > Block AI > preset > default. See RULES.md. */
(function (root) {
  const AI = root.LockInAI || (typeof require === "function" ? require("./ai-policy.js") : null);
  function normalizeDomain(input) {
    const raw = String(input).trim();
    if (!raw || /\s|\\/.test(raw) || /[^\x00-\x7f]/.test(raw)) return null;
    try {
      const url = new URL(raw.includes('://') ? raw : 'https://' + raw);
      if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || (url.port && (+url.port < 1 || +url.port > 65535))) return null;
      const host = url.hostname.toLowerCase().replace(/\.$/, '');
      if (host.length > 253 || !host.split('.').every(s => s.length && s.length <= 63 && /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/.test(s))) return null;
      // Avoid WHATWG shorthand-IP interpretation differing from Foundation.
      const authority = raw.replace(/^https?:\/\//i, '').split(/[/?#]/)[0].replace(/:\d+$/, '').replace(/\.$/, '').toLowerCase();
      if (host !== authority) return null;
      return host;
    } catch { return null; }
  }
  const matches = (host, domain) => host === domain || host.endsWith('.' + domain);
  const active = (s, now = Date.now()) => !!s && s.isFocusActive === true && Number.isFinite(s.endDate) && s.endDate > now;
  function allowed(url, state, now = Date.now()) {
    if (!active(state, now)) return true;
    let parsed; try { parsed = new URL(url); } catch { return true; }
    if (!['http:', 'https:'].includes(parsed.protocol)) return true;
    const host = parsed.hostname.toLowerCase().replace(/\.$/, '');
    if (state.neverBlockDomains.some(d => matches(host, d))) return true;
    if (state.blockAI === true && AI?.isAI(parsed,state.extraAIDomains || [])) return false;
    const listed = state.domains.some(d => matches(host, d));
    return state.ruleMode === 'block' ? !listed : listed;
  }
  function valid(s) {
    return s && s.protocolVersion === 1 && typeof s.installationID === 'string' && Number.isSafeInteger(s.revision) && s.revision >= 0 &&
      ['block', 'onlyAllow'].includes(s.ruleMode) && typeof s.isFocusActive === 'boolean' && typeof s.presetName === 'string' &&
      typeof s.sessionMode === 'string' && (s.blockAI == null || typeof s.blockAI === 'boolean') && (s.extraAIDomains == null || Array.isArray(s.extraAIDomains) && s.extraAIDomains.length<=400 && s.extraAIDomains.every(d=>typeof d==='string' && normalizeDomain(d)===d)) && (s.indefinite == null || typeof s.indefinite === 'boolean') && (s.activityMode == null || ['focus', 'pomodoro'].includes(s.activityMode)) && (s.endDate == null || Number.isFinite(s.endDate)) &&
      [s.domains, s.neverBlockDomains].every(a => Array.isArray(a) && a.length <= 2000 && a.every(d => typeof d === 'string' && normalizeDomain(d) === d));
  }
  const accepts = (old, next) => valid(next) && (!old || old.installationID !== next.installationID || next.revision >= old.revision);
  function hostRegex(domain) {
    const escaped = domain.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return '^https?://([^/?#@]+@)?([a-zA-Z0-9-]+\\.)*' + escaped + '\\.?(:[0-9]+)?([/?#].*)?$';
  }
  function netRules(state, baseURL, now = Date.now()) {
    if (!active(state, now)) return [];
    let id = 1;
    const out = [];
    const allow = (domain, priority=30) => out.push({id: id++, priority, action: {type: 'allow'}, condition: {regexFilter: '^https?://.*', requestDomains: [domain], isUrlFilterCaseSensitive: false, resourceTypes: ['main_frame']}});
    state.neverBlockDomains.forEach(d=>allow(d));
    if (state.ruleMode === 'onlyAllow') state.domains.forEach(d=>allow(d,20));
    const redirect = {type: 'redirect', redirect: {regexSubstitution: baseURL + 'blocked.html#\\0'}};
    if (state.blockAI === true && AI) {
      for (const domain of [...new Set([...AI.domains,...(state.extraAIDomains || [])])]) out.push({id:id++,priority:25,action:redirect,condition:{regexFilter:'^https?://.*',requestDomains:[domain],isUrlFilterCaseSensitive:false,resourceTypes:['main_frame']}});
      for (const route of AI.pathRules()) out.push({id:id++,priority:25,action:redirect,condition:{...route,isUrlFilterCaseSensitive:false,resourceTypes:['main_frame']}});
    }
    if (state.ruleMode === 'onlyAllow') out.push({id: id++, priority: 1, action: redirect, condition: {regexFilter: '^https?://.*', resourceTypes: ['main_frame']}});
    else for (const domain of state.domains) {
      out.push({id: id++, priority: 10, action: redirect, condition: {regexFilter: '^https?://.*', requestDomains: [domain], isUrlFilterCaseSensitive: false, resourceTypes: ['main_frame']}});
    }
    return out;
  }
  root.LockInRules = {normalizeDomain, matches, active, allowed, valid, accepts, netRules};
  if (typeof module !== 'undefined') module.exports = root.LockInRules;
})(globalThis);
