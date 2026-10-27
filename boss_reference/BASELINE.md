# Reference baseline report

This is the known-good pre-modernization checkpoint for the in-repository
`boss_reference` application.

## Environment

- Chicago Boss checkout: `aaf8fca`
- Erlang/OTP: `21.3.8.24` (the repository `.tool-versions` marker)
- ERTS: `10.3.5.19`
- OS: macOS Darwin `22.5.0`, arm64
- database adapter: `mock`
- session adapter: `mock`
- HTTP adapter: Cowboy/simple_bridge
- listen address: `127.0.0.1:8001`
- session expiry: `3600` seconds
- CSRF filter: `boss_csrf_filter`

## Required checks

The following commands were run successfully from `boss_reference/`:

```text
./rebar boss c=compile              PASS
./rebar skip_deps=true eunit        PASS (7 tests)
./rebar boss c=test_functional     PASS (7 assertions)
./scripts/http_smoke.sh             PASS (session/CSRF/JSON/mutation/logout)
./scripts/websocket_smoke.sh       PASS (WebSocket 101 handshake)
```

The Chicago Boss root also compiles successfully with:

```text
./rebar compile                     PASS
```

## HTTP smoke observations

- `GET /` returned `200`, with one project and one open fixture issue.
- `GET /login` returned `200` with session and CSRF cookies and a hidden
  `csrfmiddlewaretoken` field.
- A login POST without the form token returned `403` and did not authenticate.
- A valid login POST returned `302 /` and rendered the one-request flash.
- `GET /projects/legacy-baseline` and
  `GET /issues/boss_reference_issue-4` returned `200`.
- `GET /api/issues/boss_reference_issue-4` returned JSON with string labels.
- An anonymous issue-create GET redirected to `/login`.
- A valid issue-create POST returned a custom redirect such as
  `/issues/boss_reference_issue-10`.
- Logout returned `302 /`; the same session then redirected protected issue
  mutations to `/login`.

## Known limitations

- This baseline intentionally uses the mock adapters; persistence and
  multi-node behaviour are outside its contract.
- `boss_web_test` is a continuation-based harness and does not provide a
  general cookie jar. Cookie/CSRF replay helpers are provided in
  `boss_reference_test_support.erl`; the transport WebSocket check is a
  separate server smoke test.
- The repository contains legacy parameterized-module code. The baseline
  includes compatibility fixes for tuple dispatch, Cowboy cookie headers,
  map-based request headers, and the in-repository app path so this known
  contract can execute on the pinned OTP runtime.
- Existing Chicago Boss compiler warnings, including legacy
  `erlang:get_stacktrace/0` deprecations, are recorded warnings rather than
  behavioural failures.

Do not change this application or its fixtures when starting modernization;
copy the same commands and assertions to the modernized branch and compare
the public behaviour.
