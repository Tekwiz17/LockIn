/* Curated coverage, not an AI detector. Updated with extension releases. */
(function(root) {
  const domains = ['chatgpt.com','chat.openai.com','claude.ai','gemini.google.com','aistudio.google.com','notebooklm.google.com','notebook.google','copilot.microsoft.com','copilot.com','perplexity.ai','grok.com','poe.com','chat.deepseek.com','chat.mistral.ai','lechat.mistral.ai','meta.ai','character.ai','pi.ai','you.com','phind.com','suno.com','udio.com','midjourney.com','ideogram.ai','leonardo.ai','runwayml.com','pika.art','luma.ai','lumalabs.ai','krea.ai','gamma.app'];
  const googleDomains = ['google.com','google.co.uk','google.ca','google.com.au','google.co.nz','google.de','google.fr','google.es','google.it','google.nl','google.pl','google.hu','google.co.jp','google.co.in','google.com.br','google.com.mx','google.co.za','google.com.sg','google.com.hk','google.ie','google.ch','google.at','google.be','google.dk','google.se','google.no','google.fi','google.pt','google.co.kr'];
  const matches=(host,domain)=>host===domain || host.endsWith('.'+domain);
  const googleHost=host=>googleDomains.some(d=>host===d || host==='www.'+d);
  function isAI(url,extra=[]) {
    const host=url.hostname.toLowerCase().replace(/\.$/,'');
    if ([...domains,...extra].some(d=>matches(host,d))) return true;
    if (googleHost(host) && url.pathname==='/search' && url.searchParams.getAll('udm').includes('50')) return true;
    if (['x.com','twitter.com'].some(d=>matches(host,d)) && /^\/i\/grok(?:\/|$)/.test(url.pathname)) return true;
    if (matches(host,'huggingface.co') && /^\/chat(?:\/|$)/.test(url.pathname)) return true;
    return matches(host,'bing.com') && /^\/(?:chat|copilot)(?:\/|$)/.test(url.pathname);
  }
  function webSearchURL(input) {
    let url;try {url=new URL(input);}catch{return null;}
    if(!googleHost(url.hostname.toLowerCase().replace(/\.$/,'')) || url.pathname!=='/search' || !url.searchParams.has('q'))return null;
    if(url.searchParams.get('tbm'))return null;
    const filters=url.searchParams.getAll('udm');
    if(filters.some(value=>value!=='' && value!=='0'))return null;
    url.searchParams.set('udm','14');return url.href;
  }
  function pathRules() {
    const list = [
      {regexFilter:'^https?://[^/]+/i/grok([/?#]|$)',requestDomains:['x.com','twitter.com']},
      {regexFilter:'^https?://[^/]+/chat([/?#]|$)',requestDomains:['huggingface.co']},
      {regexFilter:'^https?://[^/]+/(chat|copilot)([/?#]|$)',requestDomains:['bing.com']}
    ];
    // Domain matching belongs to the browser, keeping regex compilation small.
    list.push({regexFilter:'^https?://[^/]+/search[?]([^#]*&)?udm=(50|%35%30|5%30|%350)(&|#|$)',requestDomains:googleDomains});
    return list;
  }
  root.LockInAI={domains,googleDomains,googleHost,isAI,pathRules,webSearchURL};
  if(typeof module!=='undefined')module.exports=root.LockInAI;
})(globalThis);
