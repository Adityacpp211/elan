import { launch } from './cdp.mjs';
const b = await launch({ userDataDir: process.env.UDD });
await b.send('Page.navigate', { url: 'about:blank' }); await b.sleep(500);
console.log(await b.evaluate(`JSON.stringify(['video/mp4;codecs=avc1.640028,mp4a.40.2','video/mp4;codecs=avc1,opus','video/mp4','video/webm;codecs=vp9,opus'].map(t=>[t,MediaRecorder.isTypeSupported(t)]))`));
b.close();
