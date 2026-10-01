const {test}=require('node:test');const assert=require('node:assert/strict');const B=require('../BrowserExtensions/Shared/browser-identity.js');
test('browser naming uses native Firefox and Brave APIs and distinguishes Edge from Chrome',async()=>{
 assert.equal(await B.detect({runtime:{getBrowserInfo:async()=>({name:'Firefox'})}},{}),'Firefox');
 assert.equal(await B.detect({}, {brave:{isBrave:async()=>true},userAgent:'Chrome/130 Safari/537'}),'Brave');
 assert.equal(await B.detect({}, {userAgent:'Chrome/130 Safari/537 Edg/130'}),'Edge');
 assert.equal(await B.detect({}, {userAgent:'Chrome/130 Safari/537'}),'Chrome');
 assert.equal(await B.detect({}, {userAgent:'Version/18 Safari/605'}),'Safari');
 assert.equal(await B.detect({}, {userAgentData:{brands:[{brand:'Microsoft Edge'}]}}),'Edge');
});
test('unavailable browser identity APIs fail gracefully',async()=>{
 assert.equal(await B.detect({runtime:{getBrowserInfo:async()=>{throw Error('unavailable')}}},{brave:{isBrave:async()=>{throw Error('unavailable')}}}),'Chromium');
});
