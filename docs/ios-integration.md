# Native iOS integration requirements

## Confirmed browsing contract

- Session bootstrap: GET /api/auth/me; web login POST /api/auth/login accepts
  name/password/optional code, returns session state. Exact cookie attributes,
  expiration and native login response still need verification. Persist cookies
  and handle 401; carry CSRF on mutations without logging credential values.
- Movies: GET /api/library/movies?limit=...&offset=... -> items, total.
- Shows: GET /api/library/shows?limit=...&offset=... -> items, total.
- Home: GET /api/library/recent and /api/library/continue -> items.
- Search: GET /api/search?q=...&limit=... -> films, shows, episodes. URL-encode
  query, cancel superseded searches, display empty/error states. No search
  pagination contract has been confirmed.
- Details: GET /api/items/{id}; /api/shows/{id};
  /api/shows/{id}/seasons/{number}?limit=...&offset=... -> episodes, total.
- Resume: item progress includes position/duration/completed/started/finished.
- Artwork URLs are returned by the server; resolve relative URLs against the
  Prism origin and do not forward session credentials to unrelated hosts.
- Empty and null artwork/metadata/progress must work. Empty arrays in the audit
  do not establish their element types.

## Playback blockers

1. Capture the exact POST /api/playback/sessions body used by the player.
   scripts/capture-playback-request.js captures and blocks one such request;
   it does not start playback or prove server support for any policy.
2. Obtain the response schema, chosen file, original stream URL, expiration,
   required cookies/headers, seek/range behavior and session renewal rules.
3. Obtain an explicit server policy to forbid BOTH video and audio transcoding.
   A client preference or quality=original alone is not proof of enforcement.
   Unknown policy fields must not be guessed and treated as protection.
4. Collect actual file and track codec/container values. The audit only records
   field types. Test compatibility on the target iPhone. Track.supported has
   no established device-specific meaning.
5. Decide separately whether lossless stream-copy remuxing is permitted. It
   changes packaging without changing the audio/video codecs; the user has
   required no transcoding but has not explicitly settled remuxing.
6. Verify audio/subtitle selection and whether selecting image subtitles causes
   burn-in. Reject operations requiring transcoding under the direct-play rule.
7. Verify lifecycle: heartbeat, progress save, stop and next episode. Public web
   client uses POST session heartbeat with position/paused, POST item progress
   with position/duration/completed, and DELETE session to stop. These mutations
   have not been tested.

## Completion criteria

A native browse/search UI is achievable with the confirmed read contracts.
Playback is complete only after original video AND original audio play on the
phone, seeking/resume work, and server session evidence confirms no transcoding.
Neither an HTTP 200 nor successful simulator launch meets those criteria.

## Captured playback request — 2026-10-21T21:41:07Z

POST /api/playback/sessions was intercepted before sending. Body:

```json
{
  "movie_id": 6003,
  "quality": "original",
  "position": 3510.759873,
  "capabilities": {
    "h264": true,
    "aac": true,
    "native_hls": true,
    "hevc": false,
    "hevc_main10": true,
    "ac3": false,
    "eac3": false
  },
  "audio_index": 1
}
```

Use movie_id exactly as captured for this operation; item detail uses /items/{id}.
Position is a fractional number; its exact units should be confirmed with the
backend contract before converting to/from native player time. audio_index likely
selects the track but its mapping must be confirmed against files[].tracks[].index.
Capabilities belong to the capturing browser; do not hard-code them for iPhone.
In particular, this capture reports hevc=false and hevc_main10=true.

There is no explicit disallow-transcoding field in this captured request.
quality=original does NOT establish that audio is copied unchanged. The capture
has no response, stream URL or processing mode because it was blocked. Do not
replay it until the no-video/no-audio-transcoding contract is established.

Next read-only check: GET /api/items/6003 and inspect the actual files[].container,
video_codec, audio_codec and tracks[] values. Then obtain documented creation
policy and response from the backend owner. Do not falsify capabilities to force
a server decision, guess policy fields or set global transcode limits.

## Updated scope and native implementation

The user explicitly relaxed the no-transcoding requirement: prioritize working
playback and accept server-selected processing. A supplied ready-session response
confirmed state/mode/mode_reason/quality/position/offset/duration/generation,
stream_url, track selection and subtitle fields. HLS requests and a successful
heartbeat were observed in the user's desktop browser. That is not an iOS test.
A native SwiftUI implementation now uses these contracts for browse/search,
login, title/show details and AVPlayer sessions. No supplied session cookies or
CSRF token values have been saved in source or documentation.
