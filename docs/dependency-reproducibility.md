# Dependency reproducibility on Erlang/OTP 21.3.8.24

This document describes the dependency-only reproducibility boundary for the
historical ChicagoBoss `0.9.0` build. It is intentionally separate from the
production OTP 21.3 compatibility commit (`e56a584`) and from any future
Common Test maintenance for `boss_mq_SUITE`.

## Scope and invariants

The active historical dependency closure contains 34 Git checkouts, including
ChicagoBoss's direct dependencies and the transitive closure of `boss_db`.
The complete name, HTTPS remote, historical selector, resolved commit, and
selector classification are in [`config/dependency-lock.tsv`](../config/dependency-lock.tsv).
The legacy transport inventory, including inactive/test-only declarations, is
in [`config/legacy-dependency-urls.tsv`](../config/legacy-dependency-urls.tsv).

The immutable baseline archive is:

```text
chicagoboss-baseline-otp-21.3.8.24.tar.gz
SHA-256 cf123ea5ec3b0f28a54b99e7a6c38bb6a7d6e4f3a19c6ffb01a1663cc59a254d
```

The archive is an input to comparison only. The bootstrap process never writes
to it or to the archived baseline result directory.

The target runtime is Erlang/OTP `21.3.8.24`; OTP 21.2 is explicitly out of
scope. The supplied `.tool-versions` selects that target, and validation uses
the direct executable under:

```text
/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin/erl
```

## What changed

Only the moving `mimetypes` declaration was changed in the tracked historical
build configuration:

| File | Old declaration | New declaration | Resolved SHA | Rationale |
| --- | --- | --- | --- | --- |
| `rebar.config` | `mimetypes` Git `branch: master` | Git `ref: ee98c7603c5effb525551913745e7458c360ed70` | `ee98c7603c5effb525551913745e7458c360ed70` | A branch is moving; this is the exact commit used by the verified baseline/remediation run. |
| `rebar.config.script` | `mimetypes` Git `branch: master` | Git `ref: ee98c7603c5effb525551913745e7458c360ed70` | `ee98c7603c5effb525551913745e7458c360ed70` | Keep the legacy conditional rebar path consistent with `rebar.config`. |

No other dependency revision was changed. Tags and commit refs are preserved
as historical selectors and are checked against their full resolved SHA in the
lock manifest. The two active transitive declarations that still spell their
remote as `git://` in third-party source (`pmod_transform` in `erlando` and
`stacktrace_compat` in `simple_bridge`) are not edited in the generated local
checkouts. Instead, the lock manifest uses the equivalent HTTPS remotes and
the bootstrap clones those exact SHAs directly. This removes the network
dependency on the legacy transport without modifying vendored/generated
dependency source.

The remaining `git://` declarations are catalogued rather than silently
changed: they are inactive test profiles, old conditional syntax-tools paths,
or alternate legacy `.deps` files outside the active OTP 21.3 closure. The
top-level `Makefile`'s `git://` URL is for bootstrapping the historical rebar
tool itself, not an application dependency, and is therefore outside this
dependency-only change.

## Clean bootstrap

The historical rebar workflow is preserved. `scripts/bootstrap-deps.sh` only
materializes `deps/`; it does not replace `./rebar`, alter the Makefile, or
copy from another checkout. It has two modes:

```sh
ERL_BIN=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin/erl \
  ./scripts/bootstrap-deps.sh \
  --clean \
  --evidence-dir "$PWD/.dependency-evidence/bootstrap"
```

`--clean` removes only the checkout-local `deps/`, `ebin/`, `.rebar/`, and
`.eunit/` paths. Every row in the lock file is then cloned from its HTTPS
remote, detached at its full expected commit, and checked again with
`git rev-parse HEAD`. The evidence directory receives:

- `runtime.tsv`, including the target label, OTP release, executable, mode,
  and dependency count;
- `resolved-dependencies.tsv`, including expected SHA, actual SHA, origin, and
  `VERIFIED` status for every checkout.

To verify without network access or fetching anything:

```sh
ERL_BIN=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin/erl \
  ./scripts/bootstrap-deps.sh \
  --verify-only \
  --evidence-dir "$PWD/.dependency-evidence/verify"
```

The verifier fails if a row is missing, a checkout is not Git-managed, or its
current `HEAD` differs from the lock SHA. It also refuses to proceed under a
non-OTP-21 runtime. The normal clean run is a fresh checkout with no existing
`deps/`; a populated local dependency tree is never evidence of clean
reproducibility.

## Historical build and evidence capture

After bootstrap, run the original build path and capture its complete output:

```sh
RUN="$PWD/.dependency-evidence/clean-otp-21.3.8.24"
mkdir -p "$RUN"

PATH=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin:$PATH \
  make >"$RUN/make.log" 2>&1

PATH=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin:$PATH \
  ./rebar eunit -v skip_deps=true >"$RUN/eunit.log" 2>&1

ERL_BIN=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin/erl \
  ./scripts/capture-dependency-graph.sh "$RUN" "$RUN/make.log"
```

`capture-dependency-graph.sh` writes the checked-out ChicagoBoss commit,
worktree status, a complete application dependency text graph, a Graphviz DOT
graph, and a filtered compiler-warning report. The original `make.log` and
`eunit.log` remain the authoritative complete logs. The generated application
lane can be exercised with the supplied skeleton using the historical command:

```sh
PATH=/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin:$PATH \
  make app PROJECT=dependency_app >"$RUN/generated-app.log" 2>&1
```

The generated-app result is recorded separately because it is a consumer of
the dependency closure, not a replacement for the root build.

## Network and clean-checkout tests

There are two distinct claims to record:

1. **Normal HTTPS network:** a fresh worktree starts with no `deps/`, runs the
   bootstrap script, and clones all 34 rows from the HTTPS URLs in the lock.
   The command output and `resolved-dependencies.tsv` are retained.
2. **No pre-populated local tree:** the worktree is created from Git, its
   `deps/` absence is recorded before bootstrap, and no checkout is copied
   from the original worktree, baseline archive, or remediation archive.

If DNS, GitHub availability, credentials, or a proxy prevents the HTTPS run,
that is a `TOOLING_NETWORK` failure, not evidence that a SHA or source build
is invalid. A completed materialization followed by a compile failure is
classified independently as `BUILD`; EUnit assertion failures are `TEST`; an
application boot or request failure is `RUNTIME`; and a wrong/missing
dependency or SHA mismatch is `DEPENDENCY`.

## Dependency graph interpretation

The lock is the reproducibility manifest for source checkouts. The generated
application graph is the runtime/application-layer graph extracted from the
`.app` files after compilation. The two are deliberately kept separate:

- the lock proves which source revisions were used;
- `application-dependencies.txt` and `.dot` show OTP/application dependencies
  visible to the built artifacts;
- the complete build log shows compiler diagnostics and any rebar/tooling
  behavior;
- `resolved-dependencies.tsv` proves the actual checkout `HEAD` values.

Together these artifacts distinguish a dependency problem from a historical
rebar, compiler, test, or runtime problem without mutating the immutable
baseline.
