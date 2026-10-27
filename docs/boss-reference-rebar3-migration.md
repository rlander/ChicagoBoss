# `boss_reference` Rebar3 migration report

Status: implemented and validated on Erlang/OTP 21.3.8.24. The work is
deliberately uncommitted; the existing `artifacts/rebar3-migration-otp-21.3.8.24/`
tree is the repository evidence bundle.

## Result

The reference application now has a native Rebar3 workflow:

```sh
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 release
rebar3 tar
```

The canonical application configuration is
[`boss_reference/rebar.config`](../boss_reference/rebar.config), and the
resolved dependency set is [`boss_reference/rebar.lock`](../boss_reference/rebar.lock).
The application retains the historical ChicagoBoss source layout and
parameterized-module API. The old Rebar2 executable, Makefile, `boss_plugin`,
`init.sh`, and copied dependency workflow are not required.

The authoritative local-mirror clean run passed:

| Check | Result |
| --- | --- |
| OTP runtime | 21.3.8.24 / ERTS 10.3.5.19 |
| Rebar3 | 3.15.2, `tools/rebar3` |
| Clean dependency materialization | pass; empty `deps/`, `_build/`, `ebin/`, `.rebar/`, `.eunit/` |
| `rebar3 compile` | pass |
| `rebar3 eunit` | pass, 7 tests |
| `rebar3 ct` | pass, 1 suite/test |
| `rebar3 release` | pass |
| `rebar3 tar` | pass |
| HTTP focused checks | pass: `/` GET 200, `/` HEAD 200, static 200, unknown 404 |
| Full HTTP smoke | pass, including CSRF, cookies, login, JSON, mutation, and logout |
| WebSocket smoke | pass, HTTP 101 upgrade |

The historical app does not define `/health`; the equivalent dynamic endpoint
is `/`. `/health` is therefore recorded as not applicable rather than being
reported as a failed migration check. The generated skeleton app has its own
health route and its results are retained in the generated-app artifacts.

## Toolchain boundary

Only the pinned runtime was used:

```text
OTP:       21.3.8.24
ERTS:      10.3.5.19
Rebar3:    3.15.2
Rebar3 SHA ab1faabf45ebbd7ff54460375de2013a58a287f864d2c93c2429dd79933645c4
```

The host has globally cached Rebar3 plugins compiled for a newer OTP. OTP 21
reports `badfile`/unsupported-opcode messages while loading those cache
plugins (`pc`, `rebar3_hex`, `rebar3_ex_doc`, and others). Rebar3 continues and
the project tasks complete successfully. These messages are tooling-cache
warnings, not dependency, build, test, runtime, or packaging failures. They are
preserved in the raw logs.

## Configuration migration

`boss_reference/rebar.config` is intentionally small and expresses the
following policies:

* `src_dirs` points at `src/boss`, while the ChicagoBoss provider compiles the
  legacy controller/model/view directories once through `boss_load`.
* `project_plugins` loads the ChicagoBoss provider using Rebar3's
  `git_subdir` form.
* `provider_hooks` invokes `chicago_boss_compile` after ordinary compilation.
* the `test` profile discovers `test/` EUnit modules and `ct/` Common Test
  suites; the historical functional module remains a custom
  `boss_web_test` harness and is not relabeled as CT.
* `boss` is included in the application closure and in
  `src/boss_reference.app.src`.
* `sys.config` preserves the mock database/session adapters, Cowboy port
  `8001`, static root, CSRF filter, template escaping, and fixture startup.
* `vm.args` supplies a deterministic node name/cookie for release use. Direct
  no-node boot was used for sandboxed HTTP checks because the sandbox blocks
  `epmd`; that is an environment limitation, not an application failure.
* `post_hooks` materializes the historical `mimetypes_disp` and
  `mimetypes_map` modules before packaging. This reproduces the old build
  path's generated application metadata without a bespoke dependency
  bootstrap script.

The generated application follows the same structure through `skel/rebar3.config`.
It does not copy `deps/`, `_build/`, absolute source paths, or prebuilt BEAMs.
Repeated skeleton generation was compared in the generated-app evidence.

## Legacy compiler integration

The provider retains the historical compiler pipeline instead of rewriting
the application API. It reuses `boss_load`, `boss_controller_compiler`,
`boss_record_compiler`, and historical view compilation. The provider guard in
`priv/rebar3/chicago_boss_rebar3/src/chicago_boss_rebar3.erl` ensures that a
project's legacy sources are compiled only for the current project application;
ordinary dependencies are not recursively compiled through the root Boss
pipeline.

The clean compile verified all of the following:

* `[Req]` and `[Req, SessionID]` controllers compile and dispatch;
* controller hooks and `_routes/1` metadata are present;
* dynamic and reverse routing work;
* BossRecord models, relationships, mock save/find, and fixtures work;
* ErlyDTL templates and custom tags/filters render;
* the parameterized WebSocket callback performs the transport upgrade.

## Compatibility decisions

### ErlyDTL and tuple calls

The pinned ErlyDTL checkout was retained. Rebar3 applies the dependency-level
override:

```erlang
{overrides, [
    {override, erlydtl, [{erl_opts, [debug_info, tuple_calls]}]}
]}
```

This is a compiler configuration compatibility measure, not a source fork or
revision change. A clean build applies it to the fetched checkout and the
template/model EUnit coverage passes.

### WebSocket callback

The historical WebSocket path passes a tuple callback specification to
`erlang:apply/3`. OTP 21 requires the module atom, function atom, and complete
argument list separately. The smallest source fix is in
`src/boss/boss_service_worker.erl`:

```erlang
erlang:apply(ModuleAtom, Function, Args ++ [Module])
```

The equivalent change is included in the isolated Boss validation revision.
The WebSocket smoke test passed after this change.

### Simple Bridge session cookies

The historical response code passed a cookie string through the regular
header path. The resolved Simple Bridge/Cowboy API treats a list of cookie
values differently and emitted one header value per character. The smallest
source compatibility change is to use Simple Bridge's native cookie record
path:

```erlang
Response2 = lists:foldl(fun
    ({set_cookie, Name, Value, Options}, Acc) ->
        sbw:set_cookie(Name, Value, Options, Acc);
    ({K, V}, Acc) ->
        sbw:set_header(K, V, Acc)
end, Response1, Headers).
```

Session and CSRF cookies are represented as
`{set_cookie, Name, Value, Options}` before response normalization. This keeps
cookie semantics in Simple Bridge's native cookie path for Cowboy and other
backends; serialized Mochiweb `Set-Cookie` headers are not passed through the
generic response-header path. This preserves the public HTTP behavior and
makes browser and CSRF/login/logout smoke checks agree.

### `erlmc`

`erlmc` was not removed. It remains in the resolved transitive closure and in
the lock manifest at SHA `c5280dadc6b64912e100d812a4aa95de8dea4636`.

## Dependency and reproducibility boundary

The complete direct and transitive lock is in `boss_reference/rebar.lock`.
Every entry has an exact ref. The important direct entries are:

| Application | Remote | SHA/ref |
| --- | --- | --- |
| boss | `https://github.com/rlander/ChicagoBoss.git` | `9395d334120f49d6dc8c485582f49d4fb405ed9c` |
| boss_db | `https://github.com/ErlyORM/boss_db.git` | `40aad5dea36fbada2c9e99f73d8bd8180c01cf30` |
| tinymq | `https://github.com/ChicagoBoss/tinymq.git` | `24e8b52d679921c89144deda999039ca52c846f1` |
| erlydtl | `https://github.com/erlydtl/erlydtl.git` | `118c176f61a0c466516c30502a1498ae3c40b545` |
| jaderl | `https://github.com/erlydtl/jaderl.git` | `14a80dafd92037d041dd352466fc3ddef5ae091e` |
| gen_smtp | `https://github.com/Vagabond/gen_smtp.git` | `2ea8bb995adf32102f523cef93ae98e287ac77d1` |
| iso8601 | `https://github.com/danikp/erlang_iso8601.git` | `ae6a052017f44f995102f73993289e892af16c5d` |
| mimetypes | `https://github.com/spawngrid/mimetypes.git` | `ee98c7603c5effb525551913745e7458c360ed70` |
| mochiweb | `https://github.com/mochi/mochiweb.git` | `53a9607510b7ae4c662305fa978c73edf06c4cb2` |
| cowboy | `https://github.com/ninenines/cowboy.git` | `e0254cdcb002d26a601d087b536d2b7e9be1f1f7` |
| simple_bridge | `https://github.com/nitrogen/simple_bridge.git` | `1938ec77b499884cfbea197baf52e891adbd2418` |
| cowlib | `https://github.com/ninenines/cowlib.git` | `8588724cf91ddbb53b9c35ed665866556b217323` |
| ranch | `https://github.com/ninenines/ranch.git` | `3190aef88aea04d6dce8545fe9b4574288903f44` |
| dynamic_compile | `https://github.com/JacobVorreuter/dynamic_compile.git` | `6a165715178dae8ea1c72e6ef171b9fc3435badc` |
| goldrush | `https://github.com/DeadZen/goldrush.git` | `8f1b715d36b650ec1e1f5612c00e28af6ab0de82` |
| proper | `https://github.com/manopapad/proper.git` | `f2b7b81666b21707244a40857cf50f4362b6e3c2` |
| pmod_transform | `https://github.com/erlang/pmod_transform.git` | `f96b8b572395581d58fe3dd7c3e61f3f0e8fa6dc` |
| stacktrace_compat | `https://github.com/g-andrade/stacktrace_compat` | `fe6238499a216f6f94836be9ec0b3956ea5c6101` |

The lock contains 35 entries including `aleppo`, `boss_test`, `ddb`,
`dh_date`, `epgsql`, `erlando`, `erlmc`, `ets_cache`, `ibrowse`, `jsx`,
`lager`, `medici`, `mysql`, `poolboy`, `redo`, `tiny_pq`, and `uuid`.
The complete URL/SHA rows and profile-specific dependency graphs are retained
under `artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/`.

The clean validation used local bare mirrors because the current feature
branch's Boss/provider revisions are not yet published to the configured
remote. This proves empty-tree Rebar3 materialization and SHA resolution, but
it does not claim an external clean checkout can fetch unpublished commits.
After publishing the provider and Boss revisions, replace only the temporary
local mirror URLs with the canonical HTTPS URLs; do not change the locked
third-party SHAs.

## Generated application result

The supplied skeleton was generated in an isolated directory and validated
through Rebar3. Compile, EUnit, CT, release, and tar results are recorded in
`artifacts/rebar3-migration-otp-21.3.8.24/generated-clean/` and the generated
HTTP run is under `generated-final-http/`. The generated app's `/health`
endpoint, static file, unknown route, and package contents were checked. The
generated result is separate from the canonical `boss_reference/` fixture.

The skeleton currently points at the verified remote boundary. Until the
feature-branch Boss/provider commits are published, an external checkout must
use a published equivalent or cannot resolve those two refs. This is a
dependency/publication boundary, not a reason to copy a local `deps/` tree.

## Warnings and logs

Raw logs are retained under the migration artifact tree. The final clean
reference compile emitted 54 warning lines, primarily legacy warnings from
dependencies and ChicagoBoss (`export_all`, deprecated `random`,
`crypto:rand_uniform/2`, `ssl_accept`, and `erlang:get_stacktrace/0`). They
are recorded separately from failures. The application compile, tests, and
packaging exit statuses are zero.

Runtime logs show successful startup:

```text
START={ok,[crypto,boss,boss_reference]}
GET / 200
HEAD / 200
GET /no-such-route 404
GET /login 200
POST /login 403, 403, 403, 302
GET /api/issues/boss_reference_issue-4 200
POST issue creation 302
POST /logout 302
```

## Failure classification

| Observation | Classification | Disposition |
| --- | --- | --- |
| OTP21 cannot load newer globally cached Rebar3 plugin BEAMs | tooling/version | preserved as cache noise; pinned Rebar3 project tasks pass |
| First runtime invocation used `_build/default/sys.config` | tooling/invocation | corrected to `config/sys.config`; no application conclusion drawn from it |
| Historical `boss_web_test` harness conflicts with an already-started app when run after boot | test/tooling | retained as historical harness behavior; canonical EUnit/CT and HTTP smoke are independent |
| `/health` absent in `boss_reference` | test scope | not applicable; `/` is the reference dynamic endpoint |
| `epmd`/named release foreground boot is blocked by the sandbox | tooling/environment | direct no-node boot passed; generated release assembly/tar passed |
| Current feature-branch Boss/provider refs are unpublished | dependency/publication | external clean-checkout boundary; local-mirror clean resolution passed |
| Final in-sandbox root rerun could not fetch locked `boss_db`/`boss_test` over HTTPS | network/tooling | recorded as a transport failure; the isolated approved-HTTPS clean run and the authoritative local-mirror reference run passed |
| Root `boss_mq_SUITE:test_poll` stale setup/result-shape failure | test maintenance | unchanged and separate from this migration, per request |

No dependency, build, EUnit, Common Test reference-app, runtime, or packaging
failure remains in the authoritative local-mirror run.

## Changed files and separation

Reference-app migration files:

* `boss_reference/rebar.config`, `boss_reference/rebar.lock`, `.gitignore`;
* `boss_reference/config/sys.config`, `config/vm.args`, and `src/*.app.src`;
* `boss_reference/ct/boss_reference_SUITE.erl`;
* `boss_reference/test/boss_reference_model_test.erl` and
  `test/boss_reference_websocket_smoke.erl` (test discovery only);
* `boss_reference/scripts/*.sh`, `README.md`, and `BASELINE.md`.

Shared Rebar3/provider files:

* `rebar.config` and `skel/rebar3.config` for canonical compiler hooks;
* `priv/rebar3/chicago_boss_rebar3/src/chicago_boss_rebar3.erl` for the
  project-application guard;
* `skel/config/vm.args` and skeleton configuration for generated apps.

Production compatibility files kept separate from dependency/test maintenance:

* `src/boss/boss_controller_lib.erl`;
* `src/boss/boss_erlydtl_tags.erl`;
* `src/boss/boss_router_controller.erl`;
* `src/boss/boss_service_worker.erl`;
* `src/boss/boss_web_controller_handle_request.erl`;
* `src/boss/filters/boss_csrf_filter.erl`.

`ct/boss_mq_SUITE.erl` was not changed. The immutable archive
`chicagoboss-baseline-otp-21.3.8.24.tar.gz` was not overwritten.

## Reproduction commands

For an external checkout after publication of the feature refs:

```sh
asdf install                 # resolves the checked-in OTP 21.3.8.24 marker
export PATH="$PWD/tools:$PATH"
rebar3 version
rm -rf deps ebin .rebar .eunit _build
rebar3 compile
rebar3 eunit
rebar3 ct
rebar3 release
rebar3 tar
```

The migration does not use `bootstrap-deps.sh`; Rebar3 fetches the lock and
verifies exact revisions itself. The old bootstrap script remains only as
historical investigation evidence and is not part of the application workflow.
