/* Browser naming only; no fingerprint or page content is stored. */
(function(root){
 async function detect(api=root.browser || root.chrome, nav=root.navigator || {}) {
  try {if(api?.runtime?.getBrowserInfo){const info=await api.runtime.getBrowserInfo();if(/firefox/i.test(info.name))return 'Firefox';}}catch{}
  try {if(await nav.brave?.isBrave())return 'Brave';}catch{}
  const brands=nav.userAgentData?.brands || [];
  if(brands.some(b=>/brave/i.test(b.brand)))return 'Brave';
  if(brands.some(b=>/microsoft edge/i.test(b.brand)))return 'Edge';
  const ua=nav.userAgent || '';
  if(/Edg\//.test(ua))return 'Edge';
  if(/Firefox\//.test(ua))return 'Firefox';
  if(/Brave\//.test(ua))return 'Brave';
  if(/Chrome\//.test(ua) || brands.some(b=>/google chrome/i.test(b.brand)))return 'Chrome';
  if(/Safari\//.test(ua) || api?.runtime?.getURL?.('')?.startsWith('safari-web-extension:'))return 'Safari';
  return 'Chromium';
 }
 root.LockInBrowser={detect};if(typeof module!=='undefined')module.exports=root.LockInBrowser;
})(globalThis);
