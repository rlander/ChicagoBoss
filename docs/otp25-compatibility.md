# OTP 25 compatibility

## Scope

The active root project and `boss_reference/` are validated with Erlang/OTP
25.3.2.21 (ERTS 13.2.2.16). The selected Rebar3 executable is 3.22.1. The
historical OTP 21.3.8.24 result remains available as archived evidence; this
change does not rewrite that baseline.

The source compatibility floor remains OTP 21.3. This is intentional: the
legacy Chicago Boss compiler and parameterized-controller pipeline are still
part of the application. OTP 25 is the active, tested toolchain rather than a
claim that the historical source floor has been removed.

## Changes

- Changed the root `.tool-versions` entry to `erlang 25.3.2.21`.
- Kept `boss_reference/.tool-versions` at `erlang 25.3.2.21`.
- Replaced the active checked-in `tools/rebar3` executable with the official
  Rebar3 3.22.1 escript, compiled for a runtime that can load on OTP 25.
- Preserved `tools/rebar3-3.15.2` as the historical OTP 21 tool and evidence
  boundary; dependency revisions were not changed for this migration.
- Generalized the Erlando and shell-startup comments in the root, skeleton,
  and reference configurations to describe OTP 25/Rebar3 3.22.1.
- Updated the active README and changelog toolchain statements.
- Isolated the three view-loader EUnit cases in a unique temporary output
  directory and removed their generated beam afterwards. OTP 25/Rebar3 can
  otherwise leave a generated `test_good_dtl.beam` in the project root, which
  can be mistaken for a stale test module on the next run.

No production dependency revision or compatibility patch was changed in this
step. The existing Erlando transform, Lager pin, Simple Bridge compatibility
code, custom legacy compiler provider, and reloader remain in use.

## Validation

All commands below used the OTP 25 installation selected explicitly in `PATH`
and the checked-in `tools/rebar3` executable. Builds used the normal Rebar3
`_build` directory, so the tracked legacy compiler provider and custom
development reloader were exercised.

| Check | Result |
| --- | --- |
| Root clean `rebar3 compile` | PASS |
| Root `rebar3 eunit` | PASS, 38 tests |
| Root unchanged `rebar3 ct` | One known failure in `boss_mq_SUITE:test_poll`; no suite source was changed |
| `boss_reference` clean `rebar3 compile` | PASS |
| `boss_reference` `rebar3 eunit` | PASS, 7 tests |
| `boss_reference` `rebar3 ct` | PASS, 1 test |
| `boss_reference` `rebar3 shell` | PASS; Boss and the reference app booted on port 8001 |
| `boss_reference/scripts/http_smoke.sh` | PASS; login/CSRF, redirects, API, mutation, and logout checks passed |

The root Common Test failure is unchanged test behavior, not an OTP 25 compile
failure. `boss_mq_SUITE:test_poll` calls the global `boss_mq` process without
starting it and therefore reports:

```text
{noproc,{gen_server,call,[{global,boss_mq},{push,"test","Test Message"}]}}
```

Updating that suite is separate test-maintenance work and is deliberately not
part of this compatibility change.

## Compiler warnings

Compilation succeeds, but the historical dependency graph emits warnings. The
main families are:

- removed `erlang:get_stacktrace/0` calls;
- removed `crypto:hmac/3` and `ssl:ssl_accept/3` calls;
- deprecated crypto/random, HTTPD, and TLS APIs;
- `export_all` in historical test and support modules;
- unused variables and ambiguous legacy calls such as `atom_to_binary/1`.

These are recorded as dependency-modernization warnings, not build blockers.
They should be addressed in a later dependency/API modernization effort, with
the exact dependency and module retained in the compiler log for each change.

## Reproduction

From a clean checkout with OTP 25.3.2.21 selected:

```sh
rm -rf _build deps ebin .rebar .eunit
PATH="$HOME/.asdf/installs/erlang/25.3.2.21/bin:$PATH" ./tools/rebar3 compile
PATH="$HOME/.asdf/installs/erlang/25.3.2.21/bin:$PATH" ./tools/rebar3 eunit
PATH="$HOME/.asdf/installs/erlang/25.3.2.21/bin:$PATH" ./tools/rebar3 ct

rm -rf boss_reference/_build boss_reference/deps
(cd boss_reference && \
  PATH="$HOME/.asdf/installs/erlang/25.3.2.21/bin:$PATH" ../tools/rebar3 compile && \
  PATH="$HOME/.asdf/installs/erlang/25.3.2.21/bin:$PATH" ../tools/rebar3 eunit && \
  PATH="$HOME/.asdf/installs/erlang/25.3.2.21/bin:$PATH" ../tools/rebar3 ct)
```

Start the reference app with `rebar3 shell` and run
`boss_reference/scripts/http_smoke.sh` in another terminal. The HTTP smoke
requires permission to bind/connect to the local port when run in a restricted
sandbox.

Runs that set an isolated `REBAR_BASE_DIR` can bypass relative post-hooks and
load the original MochiWeb reloader from a dependency checkout. That produces
noisy `enotdir` diagnostics unrelated to the canonical application path. The
normal `_build` workflow compiles and loads the tracked custom reloader.

## Remaining work

The next compatibility step is dependency modernization: remove or replace
the legacy APIs listed above and revalidate the full lock graph. Separately,
the stale `boss_mq_SUITE` setup/result expectation can be maintained without
mixing that test change into the production OTP 25 compatibility work.
