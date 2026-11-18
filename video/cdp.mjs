// Minimal Chrome DevTools Protocol driver for headless Edge (no dependencies).
import { spawn } from 'node:child_process';
const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const sleep = ms => new Promise(r => setTimeout(r, ms));

export async function launch({ port = 9334, userDataDir, width = 1080, height = 1920 } = {}) {
  const proc = spawn(EDGE, ['--headless=new', '--no-first-run', '--hide-scrollbars', `--remote-debugging-port=${port}`,
    `--user-data-dir=${userDataDir}`, '--allow-file-access-from-files', '--autoplay-policy=no-user-gesture-required',
    '--force-device-scale-factor=1', `--window-size=${width},${height}`, 'about:blank'], { stdio: 'ignore' });
  let targets = [];
  for (let i = 0; i < 60 && !targets.length; i++) {
    try { targets = (await (await fetch(`http://127.0.0.1:${port}/json`)).json()).filter(t => t.type === 'page'); } catch {}
    if (!targets.length) await sleep(300);
  }
  const ws = new WebSocket(targets[0].webSocketDebuggerUrl);
  await new Promise(r => (ws.onopen = r));
  let id = 0; const pending = new Map();
  ws.onmessage = e => { const m = JSON.parse(e.data); if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); } };
  const send = (method, params = {}) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params })); });
  const evaluate = async expr => {
    const m = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
    if (m.result?.exceptionDetails) throw new Error(JSON.stringify(m.result.exceptionDetails).slice(0, 600));
    return m.result?.result?.value;
  };
  await send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false });
  return { send, evaluate, sleep, close: () => { ws.close(); proc.kill(); } };
}
