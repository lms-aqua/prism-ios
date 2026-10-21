// Paste this entire file into the signed-in Prism browser console.
// GET requests only. No cookies, credentials or response values are exported.
(async () => {
  const results = [];
  const blocked = /token|secret|password|cookie|csrf|authorization/i;
  function schema(value, depth = 0) {
    if (value === null) return 'null';
    if (Array.isArray(value)) return {
      type: 'array', sample: value.length ? schema(value[0], depth + 1) : null
    };
    if (typeof value !== 'object') return typeof value;
    if (depth >= 8) return {fields: Object.keys(value).filter(k => !blocked.test(k))};
    return Object.fromEntries(Object.entries(value)
      .filter(([key]) => !blocked.test(key))
      .map(([key, val]) => [key, schema(val, depth + 1)]));
  }
  async function check(path) {
    try {
      const response = await fetch(path, {
        credentials: 'same-origin', signal: AbortSignal.timeout(20000)
      });
      let data;
      try { data = await response.json(); } catch {}
      results.push({path, status: response.status,
        contentType: response.headers.get('content-type'),
        errorCode: !response.ok && typeof data?.code === 'string' ? data.code : undefined,
        schema: data === undefined ? 'Non-JSON response' : schema(data)});
      console.log(response.status, path);
      return response.ok ? data : null;
    } catch (error) { results.push({path, error: error.name}); return null; }
  }
  const paths = [
    '/api/auth/status', '/api/auth/me',
    '/api/library/movies?limit=1&offset=0',
    '/api/library/shows?limit=1&offset=0',
    '/api/library/recent', '/api/library/continue', '/api/library/backlog',
    '/api/library/status', '/api/library/facets?kind=movie',
    '/api/library/facets?kind=episode', '/api/search?q=test&limit=1',
    '/api/watchlist', '/api/playlists', '/api/me/history?limit=1',
    '/api/me/home-layout', '/api/settings', '/api/settings/maintenance',
    '/api/notices', '/api/shelves', '/api/plugins/home', '/api/watch-link/supported'
  ];
  const data = {};
  for (const path of paths) data[path] = await check(path);
  const movie = data['/api/library/movies?limit=1&offset=0']?.items?.[0];
  const show = data['/api/library/shows?limit=1&offset=0']?.items?.[0];
  if (movie?.id != null) {
    const id = encodeURIComponent(movie.id);
    for (const suffix of ['', '/subtitles', '/segments', '/chapters', '/bookmarks',
      '/provenance', '/commentary']) await check(`/api/items/${id}${suffix}`);
    await check(`/api/plugins/title/${id}`);
  }
  if (show?.id != null) {
    const id = encodeURIComponent(show.id);
    const detail = await check(`/api/shows/${id}`);
    await check(`/api/plugins/show/${id}`);
    const seasons = detail?.seasons ?? detail?.show?.seasons;
    const first = Array.isArray(seasons) ? seasons[0] : null;
    const number = typeof first === 'number' ? first : first?.season_number ?? first?.number;
    if (number != null) {
      const season = await check(`/api/shows/${id}/seasons/${encodeURIComponent(number)}?limit=1&offset=0`);
      const episode = season?.items?.[0] ?? season?.episodes?.[0];
      const episodeId = episode?.item_id ?? episode?.id;
      if (episodeId != null) await check(`/api/items/${encodeURIComponent(episodeId)}/next`);
    }
  }
  window.prismApiAudit = {checkedAt: new Date().toISOString(),
    scope: 'Authenticated read-only schema discovery. Playback not started or verified.', results};
  const json = JSON.stringify(window.prismApiAudit, null, 2);
  const url = URL.createObjectURL(new Blob([json], {type: 'application/json'}));
  const link = document.createElement('a');
  link.href = url;
  link.download = 'prism-api-audit.json';
  document.body.appendChild(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
  console.table(results.map(({path, status, error}) => ({path, status, error})));
  console.log('Downloaded prism-api-audit.json. Report also available as window.prismApiAudit.');
})();
