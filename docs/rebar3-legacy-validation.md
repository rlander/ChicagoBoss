# Legacy Rebar3 validation record

Validated on 2026-10-25 with:

```text
Erlang/OTP 21.3.8.24 (ERTS 10.3.5.19)
Rebar3 3.15.2
```

OTP 21.2 was not installed or investigated. OTP 29 has not been validated and
is not claimed as supported.

## Root application

The clean build removed `_build` and resolved the locked dependencies with
Rebar3. Because the feature-branch provider commit was not available from the
configured public Git remote during this run, the validation used a temporary
bare Git mirror containing the same provider commit. This changes only the
test remote; dependencies were still fetched and compiled by Rebar3, with no
manually copied `deps/` tree.

```text
rebar3 compile  PASS
rebar3 eunit    PASS — 38 tests
rebar3 ct       FAIL — 1 unchanged boss_mq_SUITE test
rebar3 release  PASS — relx assembled chicagoboss-0.9.0
rebar3 tar      PASS — chicagoboss-0.9.0.tar.gz
```

EUnit includes `boss_rebar3_legacy_compatibility_test`, which compiles the
fixture through `boss_load` and verifies:

- `[Req]` parameterized controller actions;
- `[Req, SessionID]` controller actions;
- `before_`, `after_`, and `config` hooks;
- generated `_routes/1`, dynamic route matching, and reverse routing;
- BossRecord attributes, mock database save, and find;
- ErlyDTL rendering with a variable.

The Common Test failure is unchanged and classified as `test`, not
`dependency` or `build`:

```text
boss_mq_SUITE:test_poll
{noproc,{gen_server,call,[{global,boss_mq},{push,"test","Test Message"}]}}
```

`ct/boss_mq_SUITE.erl` was not modified. Starting `boss_mq` and updating its
stale poll tuple expectation remain a separate test-maintenance change.

## Generated application

The generated `cb_tut` application was rebuilt after deleting its `_build`
directory. Its source retains the parameterized controller convention and its
Rebar3 provider invoked the historical compiler once.

```text
rebar3 compile  PASS
rebar3 eunit    PASS — no generated tests
rebar3 ct       PASS — no generated suites
rebar3 release  PASS
rebar3 tar      PASS
```

The generated application booted from the Rebar3-built output on port 18001.
The runtime matrix was:

| Request | Result |
| --- | --- |
| `GET /health` | `200`, body `ok` |
| `HEAD /health` | `200`, no response body |
| `GET /static/favicon.ico` | `200`, 4030-byte icon |
| `GET /unknown` | `404`, no-route response |

The shell log recorded `GET /health 200`, `HEAD /health 200`, and
`GET /unknown 404`. The static response was served by Cowboy's static
dispatcher before the dynamic Simple Bridge path.

## Warning and failure classification

The compiler warning output is retained in the run logs and consists of legacy
warnings from the dependency closure and framework, including `export_all`,
deprecated `erlang:get_stacktrace/0`, deprecated crypto/SSL calls in old
dependencies, unused variables, and old application metadata warnings. These
are classified as `build/warning`, not failures.

The remaining known boundaries are:

| Classification | Result |
| --- | --- |
| dependency | no unresolved or SHA-mismatched dependency in the validated lock |
| tooling/version | Rebar3 3.15.2 runs on OTP 21.3.8.24; OTP 29 unvalidated |
| network | public clean checkout is blocked until the provider commit is published; restricted sandbox cannot resolve GitHub |
| build | root and generated builds pass through Rebar3 |
| test | unchanged `boss_mq_SUITE:test_poll` fails on setup/result-shape assumptions |
| runtime | generated HTTP smoke matrix passes |
| packaging | root and generated release/tar commands pass, with relx missing-call warnings for optional legacy paths |

The immutable baseline archive and its recorded digest were not modified.
