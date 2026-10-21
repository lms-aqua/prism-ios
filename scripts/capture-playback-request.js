// Paste into the signed-in Prism console, then press Play or Resume once.
// Intercepts one playback-session POST BEFORE sending it. No stream is started.
// Reloading the page or calling prismStopPlaybackAudit() restores normal fetch.
(() => {
  if (window.prismStopPlaybackAudit) window.prismStopPlaybackAudit();
  const original = window.fetch;
  let timer;
  let wrapped;
  function stop() {
    if (window.fetch === wrapped) window.fetch = original;
    clearTimeout(timer);
    delete window.prismStopPlaybackAudit;
  }
  function sanitize(value) {
    if (Array.isArray(value)) return value.map(sanitize);
    if (!value || typeof value !== 'object') return value;
    return Object.fromEntries(Object.entries(value)
      .filter(([key]) => !/token|password|secret|cookie|csrf|authorization/i.test(key))
      .map(([key, val]) => [key, sanitize(val)]));
  }
  wrapped = async function(input, init) {
    const url = new URL(input instanceof Request ? input.url : input, location.href);
    const method = (init?.method ?? (input instanceof Request ? input.method : 'GET')).toUpperCase();
    if (url.origin !== location.origin || url.pathname.replace(/\/$/, '') !== '/api/playback/sessions' || method !== 'POST') {
      return original.call(window, input, init);
    }
    // Do not call original here: creating a session may start transcoding.
    stop();
    try {
      const request = new Request(input, init);
      const body = await request.clone().json();
      const report = {
        capturedAt: new Date().toISOString(), method, path: url.pathname,
        blockedBeforeSend: true, requestBody: sanitize(body)
      };
      window.prismPlaybackAudit = report;
      const json = JSON.stringify(report, null, 2);
      console.log('PLAYBACK REQUEST CAPTURED AND BLOCKED', json);
      const blobUrl = URL.createObjectURL(new Blob([json], {type: 'application/json'}));
      const link = document.createElement('a');
      link.href = blobUrl;
      link.download = 'prism-playback-request.json';
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(blobUrl), 60000);
    } catch (error) {
      console.error('Request blocked, but capture failed:', error.name);
    }
    throw new DOMException('Prism API audit blocked playback before sending the session request.', 'AbortError');
  };
  window.fetch = wrapped;
  window.prismStopPlaybackAudit = stop;
  timer = setTimeout(stop, 120000);
  console.log('Ready: press Play or Resume ONCE within two minutes. The session request will be blocked and downloaded. An expected playback error may appear. Reload the page afterward.');
})();
