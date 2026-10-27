# Chicago Boss reference application

`boss_reference` is the Rebar3-native behavioural fixture for Chicago Boss.
It deliberately keeps the historical `src/controller`, `src/model`, `src/view`,
`src/lib`, `src/test`, and `src/websocket` layout so the legacy compiler
provider is exercised without rewriting the application API.

The app uses the mock database and mock session adapter. Its fixtures are
deterministic and do not require an external database.

## Rebar3 workflow

Run these commands from this directory with OTP 21.3.8.24 and the repository's
pinned Rebar3 3.15.2 executable on `PATH`:

```sh
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 release
rebar3 tar
```

The old bundled Rebar, Makefile, `boss_plugin`, `init.sh`, and `boss.config`
are intentionally not part of the active workflow. Dependencies are resolved
by Rebar3 and recorded in `rebar.lock`; no dependency tree is copied into this
directory.

The server listens at `http://127.0.0.1:8001/`. Boot it through a Rebar3
shell or release after compiling. The startup fixture module seeds the
owner/member, project, issues, comment, labels, and join rows.

Fixture credentials are intentionally non-secret test data: `owner / owner`
and `member / member`.

The historical functional module remains a custom `boss_web_test` harness and
is not misclassified as Common Test. The real CT suite only checks that the
compiled application descriptor and generated modules are available.

## Smoke checks

With the application running, execute:

```sh
./scripts/http_smoke.sh
./scripts/websocket_smoke.sh
```

The HTTP smoke covers session and CSRF rejection/acceptance, JSON, protected
routes, mutation, and logout. The WebSocket check performs a transport-level
upgrade of `/websocket/activity` and asserts `101 Switching Protocols`.

## Behavioural surface

- public dashboard, project pages, issue filtering, nested associations, and
  escaped user-visible text;
- login, logout, session-backed flash messages, authorization, and protected
  mutation forms;
- custom routes, route-generated links, reverse routing, and JSON issue data;
- ErlyDTL templates, custom filter/tag modules, and mock database fixtures;
- the authenticated project-scoped activity WebSocket.

See [`BASELINE.md`](BASELINE.md) for the immutable historical Rebar2 result
and known runtime limitations. The migration evidence is recorded under the
repository's Rebar3 migration artifacts and `plan-rebar3-migration.md`.
