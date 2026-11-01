# OTP 24 compatibility work

This document tracks the smallest consumer-side change needed to compile the
current ChicagoBoss dependency graph on Erlang/OTP 24.3.4.17. It deliberately
does not replace `boss_db` or fork Erlando.

## Applied compatibility changes

Validation environment:

```text
Erlang/OTP 24.3.4.17 (erts-12.3.2.17)
Rebar3 3.15.2
```

The root build and `boss_reference` were both rebuilt after removing their
generated `_build` directories. Rebar3 fetched dependencies into its own
build directory; no manually copied `deps/` directory was used. The published
provider revision below is used so a clean checkout can resolve the project
plugin. The earlier `9395d334...` provider revision was not available from the
configured remote and is therefore a clean-checkout tooling/reproducibility
failure, not an application compatibility result.

The current legacy Erlando revision remains locked at:

```text
ChicagoBoss/erlando
680688f246d84a2be6ce35764f3cb4f8356008f9
```

The Rebar3 configuration now overrides only Erlando's compiler options:

```erlang
{override, erlando, [{erl_opts, [
    debug_info,
    warnings_as_errors,
    {parse_transform, do},
    {parse_transform, stacktrace_transform}
]}]}
```

`stacktrace_transform` is supplied by the existing locked
`stacktrace_compat` dependency. It rewrites Erlando's historical
`erlang:get_stacktrace/0` call while retaining the legacy `do` and `cut`
transforms.

Lager is pinned to the verified OTP 24-compatible revision:

```text
erlang-lager/lager
459a3b2cdd9eadd29e5a7ce5c43932f5ccd6eb88
```

The same settings are present in the root application, the supplied skeleton,
and `boss_reference`.

The exact Lager revision is declared in all three Rebar3 configurations and in
both checked-in lock files. The provider reference was likewise updated in the
root configuration, skeleton, and reference application from the unpublished
revision to:

```text
rlander/ChicagoBoss
f85e283cee34934bf12fe89df2e55f4d8ccd7c45
```

This does not change the production compatibility source pipeline; it makes
the already-published provider resolvable from a clean checkout.

## Warning ledger

Warnings are evidence, not a reason to hide problems. The validation logs must
be retained and each warning classified as either harmless legacy metadata,
deprecated API debt, or a runtime-risking compatibility issue.

Known warnings before this change include:

| Area | Examples | Classification | Follow-up |
| --- | --- | --- | --- |
| ChicagoBoss sources | `erlang:get_stacktrace/0` in `boss_log_util`, `boss_service_worker`, and `boss_simple_bridge_handler` | Runtime-risking deprecated API | Replace with `Class:Reason:Stack` catches or apply a narrowly scoped compatibility transform after the OTP 24 baseline is green |
| Erlando | `erlang:get_stacktrace/0` in `src/test.erl` | Build blocker | Addressed by the Erlando-only `stacktrace_transform` override |
| Lager 3.6.7 | `integer_to_list({Line, Column})` in `lager_transform` | Build blocker on OTP 24 | Addressed by pinning Lager 3.9.2 |
| Legacy dependencies | `crypto:hmac/3`, `crypto:block_encrypt/4`, `ssl:ssl_accept/*`, `erl_scan:token_info/2` | Deprecated or removed API | Exercise affected runtime paths, then migrate dependencies or add focused compatibility patches |
| Generated/test helpers | `export_all`, unused variables, old application metadata | Mostly diagnostic noise | Record counts and retain logs; clean up only when behavior is unaffected |
| Rebar3 3.15.2 | Error-reporting path calls `erlang:get_stacktrace/0` on OTP 24 | Tooling failure | Upgrade or patch the build tool after the application dependency graph is green |

Every validation run should capture compiler output, then update this table
with the exact warning count and affected files.

### OTP 24 warning inventory

The clean root compile produced 30 warnings:

| Count | Area | Examples | Classification |
| ---: | --- | --- | --- |
| 17 | ChicagoBoss | `export_all flag enabled` in legacy adapters, compiler modules, and `boss_web.hrl` | Legacy compiler design; cleanup is optional and potentially behavior-affecting |
| 9 | ChicagoBoss | `get_stacktrace/0 is removed` in `boss_service_worker`, `boss_log_util`, and `boss_simple_bridge_handler` | Deprecated API debt; exception paths need modernization and runtime coverage |
| 4 | ChicagoBoss | unused `SSLEnable`, `SSLOptions`, `ServerConfig`, and `Req` variables | Diagnostic-only unless the surrounding control flow is changed |

The clean `boss_reference` compile produced 74 warnings. These include the 30
ChicagoBoss warnings above plus dependency-owned warnings:

| Count | Dependency | Warning family | Classification / next action |
| ---: | --- | --- | --- |
| 21 | Cowboy | removed `erlang:get_stacktrace/0` | Upgrade or patch Cowboy after checking the Simple Bridge/Cowboy API boundary |
| 11 | boss_db | `export_all`, unused imports, and repeated/previously-bound variables | Review with the boss_db dependency modernization; do not fork as part of this baseline |
| 7 | gen_smtp | removed/deprecated `ssl` and `crypto` APIs plus repeated `_App` binding | Upgrade gen_smtp or apply a narrowly scoped compatibility patch |
| 4 | Proper | repeated `_K` bindings | Check the oldest Proper revision required by the test API before changing it |
| 1 | Ranch | removed `ssl:ssl_accept/3` | Upgrade only together with the Cowboy/Simple Bridge compatibility review |

The warnings are captured in `artifacts/otp24-compile-full.log` and
`artifacts/otp24-boss-reference-compile.log`. Rebar3's repeated compile output
contains the same warnings and is retained in the EUnit and CT logs.

## Required validation

Run under OTP 24.3.4.17:

```sh
PATH="$HOME/.asdf/installs/erlang/24.3.4.17/bin:$PATH" ./tools/rebar3 compile \
  2>&1 | tee artifacts/otp24-compile.log

PATH="$HOME/.asdf/installs/erlang/24.3.4.17/bin:$PATH" ./tools/rebar3 eunit \
  2>&1 | tee artifacts/otp24-eunit.log

PATH="$HOME/.asdf/installs/erlang/24.3.4.17/bin:$PATH" ./tools/rebar3 ct \
  2>&1 | tee artifacts/otp24-ct.log
```

The unchanged `boss_mq_SUITE:test_poll` stale setup/result-shape failure must
remain classified separately as a test-maintenance failure.

The reference application must also be compiled and exercised, including:

```text
GET /health
HEAD /health
static-file request
unknown-route request
```

## Validation result

The compatibility pins are sufficient for the current OTP 24 baseline:

| Check | Result | Evidence |
| --- | --- | --- |
| Root clean `rebar3 compile` | PASS | `artifacts/otp24-compile-full.log` |
| Root EUnit | PASS, 38 tests | `artifacts/otp24-eunit.log` |
| Unchanged root Common Test | 1 known failure | `artifacts/otp24-ct.log`; `boss_mq_SUITE:test_poll` fails with `noproc` because the suite does not start `boss_mq` |
| `boss_reference` clean compile | PASS | `artifacts/otp24-boss-reference-compile.log` |
| `boss_reference` EUnit | PASS, 7 tests | `artifacts/otp24-boss-reference-eunit.log` |
| `boss_reference` Common Test | PASS, 1 test | `artifacts/otp24-boss-reference-ct.log` |
| `boss_reference` HTTP smoke | PASS | `artifacts/otp24-boss-reference-http.log`; startup/runtime request logs are in `boss_reference/log/` |

The HTTP smoke exercised login, protected routing, CSRF rejection and success,
API retrieval, issue creation, logout, and post-logout protection. The runtime
log includes successful `GET /login`, protected-route redirects, API `200`, and
the expected redirect responses. No new runtime failure was observed under
OTP 24.

The Common Test failure is not a dependency-resolution failure and must not be
fixed in this compatibility change. Any future `boss_mq_SUITE` startup or
`poll/2` tuple update belongs in a separate test-maintenance change.

## Next step after the first green OTP 24 build

The current baseline is now green for compilation, EUnit, the reference app,
and its HTTP smoke. The next phase, after the application has been migrated to
the latest supported OTP/Rebar3 combination, is dependency modernization
rather than adding more compatibility workarounds:

1. Capture the complete warning ledger and identify warnings that can become
   runtime failures on OTP 24.
2. Exercise exception paths that currently contain `get_stacktrace/0`.
3. Replace removed `crypto`, `ssl`, and `erl_scan` APIs or upgrade the specific
   dependency that owns each call.
4. Review Cowboy, Ranch, Simple Bridge, and gen_smtp as one compatibility
   group; their APIs and TLS behavior are coupled.
5. Review boss_db and Erlando separately. Preserve the legacy BossRecord API
   unless a replacement has equivalent parse-transform behavior.
6. Upgrade Rebar3 to a version supported by the target OTP, then verify its
   error reporting and lock-file behavior before changing application code.
7. Re-run the full generated-application, release, tar, and auto-reload checks.
8. Keep the Common Test `boss_mq_SUITE` maintenance decision separate from this
   compatibility change.

The dependency work should be staged in small, independently testable changes:

```text
OTP/Rebar3 toolchain
        -> Cowboy/Ranch/Simple Bridge HTTP boundary
        -> gen_smtp crypto/TLS APIs
        -> boss_db/Erlando parse transforms
        -> ChicagoBoss removed stacktrace calls
        -> generated app, packaging, auto-reload, and full runtime matrix
```

Do not replace all dependencies at once. For each candidate upgrade, record
the old lock SHA, new lock SHA, compiler warning delta, affected API surface,
EUnit/CT result, reference HTTP result, and rollback point.

The baseline archive and the historical dependency revisions remain immutable.
