# Clean dependency reproducibility validation

Validation was performed after the dependency-only commits on branch
`rlander/otp-21.3.8.24-baseline-remediation`:

```text
8c3e8af  Lock historical dependency closure for OTP 21.3
c7e2d14  Fix dependency graph evidence capture
c2f9af0  Make dependency graph output OTP 21 compatible
```

The production compatibility patch remains the earlier commit `e56a584`, and
`ct/boss_mq_SUITE.erl` was not changed.

## Runtime and clean-worktree boundary

The validation worktree was created at:

```text
/private/tmp/chicagoboss-dependency-validation.KfUEpE
```

It was detached from `c2f9af0`, then `scripts/bootstrap-deps.sh --clean` was
run with:

```text
ERL_BIN=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin/erl
```

The bootstrap cloned the lock manifest's HTTPS URLs and verified every
checkout. The final verifier reports:

```text
34 dependency checkouts verified
OTP release: 21
target label: 21.3.8.24
```

The complete evidence root is:

```text
/private/tmp/chicagoboss-dependency-validation.KfUEpE/evidence
```

An archive containing only this dependency-validation evidence (and no
baseline archive contents) is:

```text
/private/tmp/chicagoboss-dependency-reproducibility-otp-21.3.8.24.tar.gz
SHA-256 bf9b1dc34c9605eb32bc2a86e40cd059ef85a92a5fedd87c0781f5a289c09d45
```

In particular, `https-network/resolved-dependencies.tsv` contains one
`VERIFIED` row for each of the 34 locked revisions, and
`clean-build/final-sha-verification/resolved-dependencies.tsv` is the final
no-fetch verification after building and testing.

The sandboxed first HTTPS attempt failed at the first DNS lookup for
`github.com`; that is recorded in `https-bootstrap-sandbox.log` and is a
`TOOLING_NETWORK` failure. The elevated normal-HTTPS run completed all 34
clones and wrote the verified manifest under `https-network/`. No checkout was
copied from the original worktree, the immutable archive, or the remediation
archive.

## Ordered results

| Phase | Result | Classification | Evidence |
| --- | --- | --- | --- |
| HTTPS bootstrap from clean worktree | 34/34 checkouts verified | PASS / dependency | `https-network/`, `https-bootstrap-network.log` |
| Final no-fetch SHA verification | 34/34 verified | PASS / dependency | `clean-build/final-sha-verification/` |
| Historical `make` | exit 0; `boss_db` and ChicagoBoss compile lines present | PASS / build | `clean-build/make-elevated.log`, `make-elevated.status` |
| Explicit historical rebar compile | exit 0 | PASS / build | `clean-build/rebar-compile-explicit.log` |
| EUnit | exit 0; all 33 tests passed | PASS / test | `clean-build/eunit.log`, `eunit.status` |
| Common Test, unchanged suite | 0 passed, 1 failed: `noproc` when calling `boss_mq` | TEST_FAILURE / setup expectation | `clean-build/common-test-absolute.log`, `common-test-absolute/` |
| Common Test diagnostic with `boss_mq:start()` | 0 passed, 1 failed: stale `{ok, Timestamp, "Test Message"}` shape | TEST_FAILURE / test maintenance | `clean-build/common-test-diagnostic.log`, `common-test-diagnostic/` |
| Skeleton generation | exit 0 | PASS / build | `generated-app-clean/generate.log` |
| Generated skeleton build | exit 0 | PASS / build | `generated-app-clean/build.log`, `build.status` |
| Generated-app boot | `BOSS_START=ok`, server ready | PASS / runtime | `generated-app-clean/runtime-static/server.log` |
| Generated-app static request | `/static/chicago-boss.png` HTTP 200, `image/png` | PASS / runtime | `generated-app-clean/runtime-static/static.*` |
| Generated-app unknown route | `/unknown-route` HTTP 404 | PASS / runtime | `generated-app-clean/runtime-static/unknown.*` |

The untouched skeleton has no `/health` route. Its relevant generated-server
exercise is therefore the supplied static route and an unknown route; the
production compatibility branch's focused `/health` checks remain separate
from this dependency-only validation.

## Warnings and logs

The complete root build/test stream is
`clean-build/all-compile-and-test.log`. The filtered companion is
`clean-build/compiler-warnings.txt`:

- 44 compiler `Warning:` lines, mostly historical `export_all`, deprecated
  `erlang:get_stacktrace/0`, and unused-variable/type diagnostics;
- 3 rebar `WARN:` lines for the missing optional `rebar3_hex` plugin;
- no warning caused a build or EUnit exit failure.

The generated application has its own complete `generated-app-clean/build.log`
and contains the expected historical warnings from the copied ChicagoBoss
source. Runtime output is retained in `runtime-static/server.log`.

`clean-build/application-dependencies.txt` and
`clean-build/application-dependencies.dot` are the source/application graph
artifacts. Their normalized representation has zero diff against the
immutable baseline graph:

```text
baseline-application-graph-normalized.txt
clean-application-graph-normalized.txt
application-graph-comparison.diff  # empty; exit 0
```

## API and baseline comparison

The clean locked `tinymq` checkout is commit
`24e8b52d679921c89144deda999039ca52c846f1`; its compiled module exports
`push/2`. The API check is in `api-check.tsv`. The clean Simple Bridge checkout
is `1938ec77b499884cfbea197baf52e891adbd2418`; its `sbw` module exposes the
explicit response-building calls used by the existing production compatibility
patch, including `build_response/1`, `set_status_code/2`, `set_header/3`,
`set_response_data/2`, and `set_response_file/2`.

All 34 clean-worktree SHAs match the baseline source checkouts; the exact
comparison is in `baseline-sha-comparison.tsv`. The immutable archive remains
byte-for-byte unchanged:

```text
chicagoboss-baseline-otp-21.3.8.24.tar.gz
SHA-256 cf123ea5ec3b0f28a54b99e7a6c38bb6a7d6e4f3a19c6ffb01a1663cc59a254d
```

The historical build is therefore reproducible through the dependency and
compiler stages from a clean checkout, and EUnit is reproducible. The
unchanged Common Test suite is not a passing baseline: it lacks queue startup,
and after explicit startup it asserts the old scalar message shape rather than
the current list returned by `poll/2`. That remaining failure is deliberately
left for a future test-maintenance commit. It is not evidence of a missing
`tinymq:push/2` export in the clean locked checkout.

## Failure classifications and boundary

- **DEPENDENCY:** none in the clean run; all locked revisions and API checks
  pass. The moving `mimetypes/master` declaration is now pinned to
  `ee98c7603c5effb525551913745e7458c360ed70`.
- **TOOLING_NETWORK:** the restricted sandbox DNS failure and the optional
  missing `rebar3_hex` warning. The latter does not block the historical
  build.
- **BUILD:** none; root, `boss_db`, and generated application builds pass.
- **TEST:** unchanged Common Test fails for setup/result-shape reasons; EUnit
  passes all 33 tests.
- **RUNTIME:** generated skeleton boot/static/unknown-route smoke checks pass.

The reproducibility guarantee covers the active OTP 21.3.8.24 dependency
closure in `config/dependency-lock.tsv`, the historical `./rebar`/Makefile
path, and the exact Git SHAs. It does not claim that inactive legacy test
profiles, the old rebar bootstrap URL in `Makefile`, external services, or the
unchanged Common Test assumptions are modernized.
