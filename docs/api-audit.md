# Prism API audit — 2026-10-21

Scope: public deployed website and its JavaScript API client. No authenticated
requests or mutating endpoint tests were performed. This is a discovered client
inventory, not an official backend specification or a complete server route list.
The previous review did not save API schemas, so changes cannot be reliably diffed.

## Live checks

- GET /api/auth/status: 200, setup_required=false.
- GET /api/auth/me: 401.
- Library movies, shows, continue; search; watchlist; playlists; settings;
  me/history; plugins/home; watch-link/supported: 401 without a session.
- /openapi.json, /api/openapi.json, /api/docs, /api/health: 404.
- GET /api/playback/sessions and GET /api/admin/tokens: 404. A GET does not
  validate the POST playback-session creation contract, and hidden/privileged
  routes may intentionally return 404.
- The index names PlayerPage-CY530lZj.js, WatchLinkPage-QprjGCsg.js and
  SettingsPage-vU0XjJH2.js, but all three return 404, including requests with a
  fresh query string. Possible stale HTML/manifest or incomplete deployment.

## iOS integration findings

The web client uses same-origin cookies. JSON mutations send X-CSRF-Token after
login. Login accepts name, password and optional code; MFA verification has a
separate endpoint. This does not establish a supported native bearer-token flow.

Playback has create/get/update/heartbeat/stop session methods. Heartbeats include
position and paused. Progress updates use position, duration and completed.
The create-session schema and no-transcoding controls are NOT verified: the
player chunk is unavailable and there is no accessible API specification.
The web client knows TRANSCODE_BUSY, so the existence of session endpoints does
not establish a direct-play-only guarantee. Both video and audio must be checked
with authenticated media and the backend's documented playback policy.

The existing iOS app still embeds the website. It does not yet call these APIs
through a native networking layer. builder.json configures builds, not Prism APIs.

## Routes found in the public client

Source: https://prism.codystechcorner.com/assets/errorMessage-BdAqTS5p.js
Template expressions below are the deployed JavaScript's parameters, not literal
URLs. Client-only string builders (for example artwork URLs) are not exhaustive.

| Method | Client route template |
| --- | --- |
| DELETE | `/api/admin/arr/queue/${e}/${t}?blocklist=${n}` |
| DELETE | `/api/admin/automations/${e}` |
| DELETE | `/api/admin/downloads/rules/${e}` |
| DELETE | `/api/admin/library/roots/${e}?confirm=${encodeURIComponent(t)}` |
| DELETE | `/api/admin/tokens/${e}` |
| DELETE | `/api/items/${e}/bookmarks/${t}` |
| DELETE | `/api/items/${e}/commentary/${t}` |
| DELETE | `/api/items/${e}/commentary/${t}/mine` |
| DELETE | `/api/items/${e}/subtitles/${t}` |
| DELETE | `/api/library/details-sweep` |
| DELETE | `/api/library/intro-jobs/${e}` |
| DELETE | `/api/library/intro-sweep` |
| DELETE | `/api/me/history/${e}` |
| DELETE | `/api/me/home-layout` |
| DELETE | `/api/playback/sessions/${e}` |
| DELETE | `/api/playlists/${e}` |
| DELETE | `/api/playlists/${e}/items/${t}` |
| DELETE | `/api/playlists/${e}/share` |
| DELETE | `/api/shelves/${e}` |
| DELETE | `/api/subscriptions?media_type=${e}&tmdb_id=${t}` |
| DELETE | `/api/users/${e}` |
| DELETE | `/api/users/${e}/access` |
| DELETE | `/api/watch-link/streams/${e}` |
| DELETE | `/api/watchlist/${e}` |
| GET | `/api/admin/activity` |
| GET | `/api/admin/arr/indexers` |
| GET | `/api/admin/arr/movies${e?` |
| GET | `/api/admin/arr/movies/lookup?term=${encodeURIComponent(e)}` |
| GET | `/api/admin/arr/quality-profiles?service=${e}` |
| GET | `/api/admin/arr/queue` |
| GET | `/api/admin/arr/radarr/${e}/grab` |
| GET | `/api/admin/arr/root-folders?service=${e}` |
| GET | `/api/admin/arr/shows${e?` |
| GET | `/api/admin/arr/shows/lookup?term=${encodeURIComponent(e)}` |
| GET | `/api/admin/arr/system` |
| GET | `/api/admin/audit?limit=${e}` |
| GET | `/api/admin/automations` |
| GET | `/api/admin/automations/dry-run` |
| GET | `/api/admin/automations/reviews` |
| GET | `/api/admin/automations/runs` |
| GET | `/api/admin/backups` |
| GET | `/api/admin/backups/jobs/${e}` |
| GET | `/api/admin/diagnostics?${t.toString()}` |
| GET | `/api/admin/downloads${e?` |
| GET | `/api/admin/downloads/rules` |
| GET | `/api/admin/feedback${e?.includeResolved?` |
| GET | `/api/admin/host` |
| GET | `/api/admin/leaving-soon` |
| GET | `/api/admin/library/hidden?limit=50&offset=${e}` |
| GET | `/api/admin/library/overview` |
| GET | `/api/admin/library/preview?kind=${e}&id=${t}` |
| GET | `/api/admin/library/roots` |
| GET | `/api/admin/now-watching` |
| GET | `/api/admin/now-watching/${encodeURIComponent(e)}` |
| GET | `/api/admin/overview` |
| GET | `/api/admin/plugins` |
| GET | `/api/admin/plugins/sections` |
| GET | `/api/admin/refusals${e?` |
| GET | `/api/admin/refusals/vocabulary` |
| GET | `/api/admin/segments/feedback` |
| GET | `/api/admin/storage/transcode-cache` |
| GET | `/api/admin/tokens` |
| GET | `/api/admin/worklist` |
| GET | `/api/arr/shows/${e}/missing?season=${t}` |
| GET | `/api/auth/me` |
| GET | `/api/auth/status` |
| GET | `/api/collections/${e}` |
| GET | `/api/items/${e}` |
| GET | `/api/items/${e}/bookmarks` |
| GET | `/api/items/${e}/chapters` |
| GET | `/api/items/${e}/commentary` |
| GET | `/api/items/${e}/commentary/${t}` |
| GET | `/api/items/${e}/matches${t?` |
| GET | `/api/items/${e}/next` |
| GET | `/api/items/${e}/provenance` |
| GET | `/api/items/${e}/segments` |
| GET | `/api/items/${e}/subtitles` |
| GET | `/api/items/${e}/subtitles/search?language=${encodeURIComponent(t)}` |
| GET | `/api/library/backlog` |
| GET | `/api/library/coming-soon` |
| GET | `/api/library/continue` |
| GET | `/api/library/details-sweep` |
| GET | `/api/library/facets?kind=${e}` |
| GET | `/api/library/intro-jobs/${e}` |
| GET | `/api/library/intro-sweep` |
| GET | `/api/library/movies?${t.toString()}` |
| GET | `/api/library/recent` |
| GET | `/api/library/scans/${e}` |
| GET | `/api/library/shows?${t}` |
| GET | `/api/library/status` |
| GET | `/api/me/history${n?` |
| GET | `/api/me/home-layout` |
| GET | `/api/notices` |
| GET | `/api/playback/admin/streams` |
| GET | `/api/playback/sessions/${e}` |
| GET | `/api/playlists` |
| GET | `/api/playlists/${e}` |
| GET | `/api/plugins/home` |
| GET | `/api/plugins/show/${e}` |
| GET | `/api/plugins/title/${e}` |
| GET | `/api/requests/progress` |
| GET | `/api/search?q=${encodeURIComponent(e)}&limit=${t}` |
| GET | `/api/seerr/details/${e}/${t}` |
| GET | `/api/seerr/discover/${e}?${r}` |
| GET | `/api/seerr/genres/${e}` |
| GET | `/api/seerr/operations/${e}` |
| GET | `/api/seerr/related/${e}/${t}?kind=${n}&page=${r}` |
| GET | `/api/seerr/request-options?media_type=${e}&tmdb_id=${t}` |
| GET | `/api/seerr/requests` |
| GET | `/api/seerr/search?q=${encodeURIComponent(e)}&page=${t}` |
| GET | `/api/seerr/trending?page=${e}` |
| GET | `/api/seerr/users` |
| GET | `/api/settings` |
| GET | `/api/settings/maintenance` |
| GET | `/api/shelves` |
| GET | `/api/shelves/${e}/items` |
| GET | `/api/shows/${e}` |
| GET | `/api/shows/${e}/seasons/${t}?limit=200&offset=${n}` |
| GET | `/api/subscriptions/status?media_type=${e}&tmdb_id=${t}` |
| GET | `/api/users` |
| GET | `/api/users/${e}/access` |
| GET | `/api/watch-link/supported` |
| GET | `/api/watchlist` |
| GET | `/api/youtube/channels` |
| GET | `/api/youtube/channels/${e}/videos` |
| GET | `/api/youtube/search?q=${encodeURIComponent(e)}` |
| PATCH | `/api/admin/automations/${e}` |
| PATCH | `/api/admin/downloads/rules/${e}` |
| PATCH | `/api/admin/library/roots/${e}` |
| PATCH | `/api/items/${e}/metadata` |
| PATCH | `/api/playback/sessions/${e}` |
| PATCH | `/api/playlists/${e}` |
| PATCH | `/api/shelves/${e}` |
| PATCH | `/api/shows/${e}/metadata` |
| PATCH | `/api/users/${e}` |
| POST | `/api/account/change-password` |
| POST | `/api/account/mfa/disable` |
| POST | `/api/account/mfa/enable` |
| POST | `/api/account/mfa/setup` |
| POST | `/api/account/spoiler-shield` |
| POST | `/api/account/tour` |
| POST | `/api/activity/heartbeat` |
| POST | `/api/admin/arr/movies` |
| POST | `/api/admin/arr/movies/${e}/actions` |
| POST | `/api/admin/arr/movies/${e}/delete` |
| POST | `/api/admin/arr/movies/${e}/rename` |
| POST | `/api/admin/arr/radarr/${e}/actions` |
| POST | `/api/admin/arr/radarr/${e}/delete` |
| POST | `/api/admin/arr/shows` |
| POST | `/api/admin/arr/shows/${e}/actions` |
| POST | `/api/admin/arr/shows/${e}/episodes/delete` |
| POST | `/api/admin/arr/shows/${e}/episodes/search` |
| POST | `/api/admin/arr/shows/${e}/rename` |
| POST | `/api/admin/arr/shows/match` |
| POST | `/api/admin/arr/sonarr/${e}/actions` |
| POST | `/api/admin/automations` |
| POST | `/api/admin/automations/import` |
| POST | `/api/admin/automations/reviews/${e}/resolve` |
| POST | `/api/admin/backups` |
| POST | `/api/admin/backups/restore` |
| POST | `/api/admin/connections/check` |
| POST | `/api/admin/downloads/rules` |
| POST | `/api/admin/feedback/${e}/resolve` |
| POST | `/api/admin/import/jellyfin` |
| POST | `/api/admin/library/hide` |
| POST | `/api/admin/library/restore` |
| POST | `/api/admin/library/roots` |
| POST | `/api/admin/storage/transcode-cache/clear` |
| POST | `/api/admin/tokens` |
| POST | `/api/auth/login` |
| POST | `/api/auth/logout` |
| POST | `/api/auth/mfa/verify` |
| POST | `/api/auth/setup` |
| POST | `/api/diagnostics/app` |
| POST | `/api/diagnostics/browser` |
| POST | `/api/diagnostics/playback-sample` |
| POST | `/api/diagnostics/playback-summary` |
| POST | `/api/diagnostics/playback-transport` |
| POST | `/api/feedback` |
| POST | `/api/items/${e}/bookmarks` |
| POST | `/api/items/${e}/progress` |
| POST | `/api/items/${e}/segments/feedback` |
| POST | `/api/items/${e}/subtitles` |
| POST | `/api/library/details-sweep${e?` |
| POST | `/api/library/intro-sweep` |
| POST | `/api/library/scan${e?` |
| POST | `/api/library/seasons/${e}/detect-intros` |
| POST | `/api/notices/${e}/read` |
| POST | `/api/playback/sessions` |
| POST | `/api/playback/sessions/${e}/heartbeat` |
| POST | `/api/playlists` |
| POST | `/api/playlists/${e}/copy` |
| POST | `/api/playlists/${e}/items` |
| POST | `/api/playlists/${e}/items/${t}/move` |
| POST | `/api/playlists/${e}/items/bulk` |
| POST | `/api/seerr/request` |
| POST | `/api/shelves` |
| POST | `/api/subscriptions` |
| POST | `/api/users` |
| POST | `/api/users/${e}/seerr-create` |
| POST | `/api/watch-link/play` |
| POST | `/api/watch-link/resolve` |
| POST | `/api/watchlist/${e}` |
| POST | `/api/watch-together/rooms/${e}/commentary` |
| POST | `/api/watch-together/rooms/${e}/commentary/consent` |
| PUT | `/api/admin/plugins/${e}` |
| PUT | `/api/me/home-layout` |
| PUT | `/api/notices/preferences` |
| PUT | `/api/playlists/${e}/order` |
| PUT | `/api/playlists/${e}/share` |
| PUT | `/api/settings` |
| PUT | `/api/users/${e}/access` |
| PUT | `/api/users/${e}/seerr-link` |

## Authenticated browser checks supplied by the user

Verified in the user's signed-in desktop browser on 2026-10-21:

- GET /api/auth/me: 200; envelope fields user and csrf_token. Token value was
  not shared or recorded.
- GET /api/library/movies?limit=1: 200; envelope items and total. Movie fields:
  id, kind, episode, title, year, overview, tmdb_id, poster_url, backdrop_url,
  duration, effective_runtime, segments_known, available, progress, watchlisted,
  added_at.
- GET /api/library/shows?limit=1: 200; envelope items and total. Show fields:
  id, title, year, overview, poster_url, backdrop_url, seasons_count,
  episodes_count, available_episodes_count, watched_episodes_count, next_item_id,
  tmdb_tv_id, details.

These checks validate authenticated list access and top-level field names only.
Nested field schemas, pagination behavior, original media delivery, audio/video
codec compatibility and no-transcoding policy remain unverified.

## Expanded authenticated checks — 2026-10-21T21:33:07Z

User browser report: 32 GET requests, 30 HTTP 200 and two HTTP 422.
Successful groups include auth/me, movie/show/recent/continue/backlog library,
library status, movie facets, search, watchlist, playlists, history, home layout,
settings and maintenance, notices, shelves, home plugins, supported watch links,
movie detail/subtitles/segments/chapters/bookmarks/provenance/commentary/title
plugins, show detail/show plugins and season episodes.

Validation failures:
- /api/library/facets?kind=episode: 422. Accepted TV facet kind is not yet known;
  inspect the validation response before choosing a replacement.
- /api/items/7676/next: 422, requested for the movie selected from /library/movies.
  Likely an episode-only operation, but the validation body is needed to confirm.

Confirmed additional schema details: movie episode and progress may be null;
show artwork, tmdb_tv_id and details may be null. Continue-watching episode data
includes show_id, show_title, season_number, episode_number, nullable end_number
and nullable next_item_id. Progress includes numeric position/duration and boolean
completed/started/finished. Backlog returned an empty items array, so its element
schema remains unknown. Auth user includes MFA status flags.

The pasted JSON was truncated during library/status. Only HTTP statuses (not full
schemas) are available for subsequent endpoints, including item detail. No stream
was started, no media codec values were collected, and no no-transcoding policy
has been verified. Do not treat these checks as playback verification.

## Complete authenticated schema snapshot — 2026-10-21T21:36:33Z

The full sanitized browser report is saved in api-schema-snapshot.json.
It supersedes the earlier truncated report. Episode next-item GET now returns
200 when called on an episode. Facets kind=episode remains 422 VALIDATION;
no alternative kind has been verified.

### Confirmed integration contracts

- Item detail exposes files[] with id, duration, container, video_codec,
  audio_codec, width, height, hdr, tracks[] and available. Track fields include
  index, type, codec, language, title, default, forced and supported.
- These are field TYPES only. No actual codec/container values or stream URLs
  were captured. supported has no verified iPhone-specific semantics.
- Seasons are returned under show detail's seasons[]; number selects a season.
  Season detail uses episodes[] (not items[]) and includes total, limit, offset,
  show and season. Episode detail includes files[], as does next-item's item.
- Search uses films[], shows[], episodes[]; it does not use the library's
  items[] envelope. History uses items[] and next_cursor. Playlists uses
  playlists[], shelves uses shelves[], and notices uses notices[]/unread.
- Settings separates playback defaults from limits. max_transcodes and
  max_remuxes exist, but their presence does not establish a per-session
  no-transcoding policy. Do not alter global limits to enforce an app preference.
- Empty arrays do not establish the element schema. A field observed as null
  does not establish its non-null type. Models must tolerate missing artwork,
  progress, metadata and episode data as observed.

### Remaining playback contract needed

Obtain the documented playback-session creation request and response, original
media URL/authentication/range behavior, audio/subtitle selection semantics and a
server-enforced policy forbidding BOTH video and audio transcoding. Decide whether
stream-copy remuxing is acceptable separately; it is not codec transcoding.
Only then create a controlled playback session and verify selected codec values,
server processing mode and iPhone playback. No playback session was created by
this audit. There is enough schema evidence to begin native library browsing;
playback is not yet verified.

Playback request captured without sending; see playback-request-snapshot.json and ios-integration.md. quality=original observed; no explicit no-transcoding policy verified.
