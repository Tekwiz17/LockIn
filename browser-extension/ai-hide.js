/* Hide only detected Google AI UI. Never remove a result region or collect page content. */
(() => {
  if (!globalThis.LockInAI?.googleHost(location.hostname.toLowerCase().replace(/\.$/,''))) return;
  const api = globalThis.browser || chrome;
  let enabled = false, observer = null, scheduled = false, endDate = null, lastURL = location.href;
  const style = document.createElement('style');
  const markers='[data-attrid="AIOverview"], [data-attrid="AI Overview"], #m-x-content, [data-container-id="ai-overview"], .M8OgIe, .YzCcne, [data-async-type="folsrch"], [data-attrid="VisualDigestGeneratedDescription"]';
  const protectedRegion=':not(main):not([role="main"]):not(#search):not(#rso):not(#main):not(:has(#rso, #search, main, [role="main"]))';
  style.textContent = 'html.lockin-hide-ai [data-lockin-ai-hidden],'+markers.split(',').map(selector=>'html.lockin-hide-ai '+selector.trim()+protectedRegion).join(',')+' { display:none !important; } html.lockin-google-check-pending #rcnt, html.lockin-google-check-pending #rso { visibility:hidden !important; }';
  let redirecting=false;
  // Hold regular-search results until the first local policy reply to avoid an Overview flash.
  const pending=LockInAI.webSearchURL(location.href)!==null;
  if(pending)document.documentElement?.classList.add('lockin-google-check-pending');
  if(!style.isConnected)(document.head || document.documentElement).append(style);
  setTimeout(()=>{if(!redirecting)document.documentElement?.classList.remove('lockin-google-check-pending');},2000);
  function enforceRoute() {
    if(endDate && Date.now()>=endDate){enabled=false;document.documentElement?.classList.remove('lockin-hide-ai');return;}
    if(enabled && LockInAI.isAI(new URL(location.href))) {
      redirecting=true; location.replace(api.runtime.getURL('blocked.html')+'#'+location.href);
      return;
    }
    if(enabled) {
      const target=LockInAI.webSearchURL(location.href);
      if(target && !redirecting){redirecting=true;document.documentElement?.classList.add('lockin-google-check-pending');location.replace(target);}
    }
  }
  function safe(node) {
    return node && node!==document.body && node!==document.documentElement &&
      !['search','rso','main'].includes(node.id) && node.tagName!=='MAIN' && node.getAttribute('role')!=='main' &&
      !node.querySelector('#rso, #search, main, [role="main"]');
  }
  function mark(node) { if(safe(node) && !node.hasAttribute('data-lockin-ai-hidden'))node.setAttribute('data-lockin-ai-hidden',''); }
  function scan() {
    scheduled=false; enforceRoute(); if(!enabled)return;
    for(const node of document.querySelectorAll('[data-lockin-ai-hidden]'))node.removeAttribute('data-lockin-ai-hidden');
    if(!style.isConnected)(document.head || document.documentElement).append(style);
    for(const node of document.querySelectorAll(markers)) {
      const parent=node.closest('div[data-hveid], [data-mcpr]');mark(safe(parent)?parent:node);
    }
    for(const link of document.querySelectorAll('a[href]')) {
      try { const url=new URL(link.href); if(LockInAI.googleHost(url.hostname) && LockInAI.isAI(url))mark(link); } catch {}
    }
    for(const button of document.querySelectorAll('button')) { if(button.textContent.trim()==='AI Mode')mark(button); }
    for(const heading of document.querySelectorAll('h1,h2,h3,[role="heading"],span,div')) {
      if(heading.closest('a') || heading.children.length>0)continue;
      const title=heading.textContent.trim();
      if(!/^(AI Overview|AI Overviews|Visión general creada por IA|Aperçu IA|Übersicht mit KI|AIによる概要)$/i.test(title))continue;
      const candidate=heading.closest('[data-attrid="AIOverview"], [data-attrid="AI Overview"], [data-hveid], [data-mcpr]');
      let container=candidate;
      if(!container) {
        // Google also renders the label as a span inside a marked result module.
        container=heading.closest('[data-async-type], [data-container-id], section');
      }
      if(safe(container) && !container.querySelector('#rso, #search, [role="main"]'))mark(container);
    }
  }
  function queue() { if(enabled && !scheduled){scheduled=true;setTimeout(scan,0);} }
  async function refresh() {
    try {
      const verdict=await api.runtime.sendMessage({type:'check'});
      enabled=verdict.hideAI===true; endDate=verdict.endDate;
      if(!style.isConnected)(document.head || document.documentElement).append(style);
      enforceRoute();
      if(!redirecting)document.documentElement?.classList.remove('lockin-google-check-pending');
      document.documentElement?.classList.toggle('lockin-hide-ai',enabled);
      if(enabled && document.documentElement && !observer){observer=new MutationObserver(queue);observer.observe(document.documentElement,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:['class','id','data-attrid','data-async-type','data-container-id','href']});}
      if(!enabled){observer?.disconnect();observer=null;}
      if(enabled)queue();
    } catch { document.documentElement?.classList.remove('lockin-google-check-pending');enabled=false;document.documentElement?.classList.remove('lockin-hide-ai');observer?.disconnect();observer=null; }
  }
  api.runtime.onMessage.addListener(message=>{if(message.type==='policyChanged')refresh();});
  document.addEventListener('DOMContentLoaded',refresh);
  addEventListener('pageshow',refresh);addEventListener('popstate',refresh);
  document.addEventListener('visibilitychange',()=>{if(!document.hidden)refresh();});
  // SPA navigation does not dispatch popstate for Google's pushState transitions.
  // Check only the URL locally; no repeated native-server calls or page data collection.
  setInterval(()=>{
    enforceRoute();
    if(location.href!==lastURL){lastURL=location.href;refresh();queue();}
  },100);
  document.addEventListener('click',()=>{setTimeout(()=>{enforceRoute();queue();},0);},true);
  // Refresh at expiry/offline, even if a sleeping worker missed a broadcast.
  setInterval(()=>{if(!document.hidden)refresh();},5000);
  refresh();
})();
