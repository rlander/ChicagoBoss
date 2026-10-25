# Rebar3 migration and reproducibility result

This document records the Rebar3-native migration performed on the feature
branch. It is an implementation and validation record, not a replacement for
the immutable historical baseline.

## Verdict

The active ChicagoBoss application, boss_db, locked dependency closure,
generated skeleton, tests, release, and tar packaging are buildable through
Rebar3 on exactly Erlang/OTP 21.3.8.24 with Rebar3 3.15.2.

The result is PARTIALLY_RESTORED when compared with the historical workflow:

- Rebar3 compile succeeds from an empty project build state.
- The locked dependency graph materializes and every checkout SHA verifies.
- EUnit passes all 33 tests.
- The unchanged Common Test suite still fails one case because it does not
  start boss_mq; its expected poll/2 result shape is also stale. This is a
  test-maintenance failure, not a dependency failure.
- A generated application compiles, runs its zero-test EUnit and Common Test
  providers, assembles and tars a release, boots the packaged release, and
  passes the HTTP smoke matrix.
- The normal restricted sandbox cannot fetch GitHub over HTTPS. The same clean
  checkout succeeds with ordinary HTTPS access through the approved network
  path. The first result is classified as TOOLING_NETWORK, not as a lock or
  source failure.

The immutable baseline archive was not modified. Its SHA-256 remains
cf123ea5ec3b0f28a54b99e7a6c38bb6a7d6e4f3a19c6ffb01a1663cc59a254d.
ct/boss_mq_SUITE.erl was not modified.

## Scope and exact toolchain

The migration is restricted to OTP 21.3.8.24 / ERTS 10.3.5.19. OTP 21.2
was not installed or investigated.

~~~sh
export PATH="/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
./tools/rebar3 --version
# rebar 3.15.2 on Erlang/OTP 21 Erts 10.3.5.19
shasum -a 256 tools/rebar3-3.15.2
# ab1faabf45ebbd7ff544603de2013a58a287f864d2c93c2429dd79933645c4
~~~

Rebar3 3.15.2 was selected because it is an OTP-21-era release that runs on
the target runtime; using the newest Rebar3 would not establish a historical
baseline. The executable is kept in tools/ as a provenance artifact. It is
not installed over the system Rebar3.

## Configuration authority

rebar.config is now the canonical root configuration. It contains:

- minimum OTP 21.3;
- the historical warning and parse-transform options;
- exact HTTPS Git dependencies;
- test-only boss_test, EUnit options, and Common Test directory options;
- standard dev, test, and prod profiles;
- a Relx release closure;
- a Rebar3 post-compile hook for the historical mimetypes generated modules;
- a Relx overlay for those generated modules.

rebar.lock is checked in and is the only lock authority. It contains the
direct and transitive Git revisions as full 40-character refs, including the
test-only `boss_test` checkout. Rebar3 3.15.2's `as test lock` provider does
not automatically serialize a profile-only dependency into the lock file, so
the exact `boss_test` entry was added from its canonical test-profile
declaration and then verified by `rebar3 as test tree`, `rebar3 as test
compile`, and `rebar3 as test eunit`. No revision was selected manually or
changed. The complete human-readable manifest, including historical selector
and moving/immutable classification, is config/dependency-lock.tsv. The final
default and test-profile checkout comparisons are
artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/dependency-sha-comparison.tsv
and `evidence-test-final/resolved-checkouts.tsv`.

The old rebar.config.script is removed from the active path. Its conditional
Rebar 2 configuration was duplicate dependency authority and could not be the
source of truth for Rebar3. The historical Rebar 2 executable, Makefile,
Windows wrappers, custom Rebar plugin, and mix.exs are removed from the active
project workflow. The skeleton has the same disposition.

The old Rebar 2 to Rebar3 mapping is:

| Historical behavior | Rebar3 implementation |
| --- | --- |
| make / ./rebar compile | rebar3 compile |
| ./rebar eunit | rebar3 eunit |
| ./rebar ct | rebar3 ct |
| custom Rebar compiler plugin | ordinary Rebar3 application discovery and compile |
| make app / boss new | rebar3 new chicagoboss using skel/chicagoboss.template |
| make release / custom tar flow | rebar3 release / rebar3 tar |
| copied deps/ in generated applications | generated rebar.config plus generated rebar.lock |

No Rebar3 plugin was necessary. The old plugin’s useful behavior was either
standard Rebar3 compilation or an explicit, documented packaging hook.

## Dependency graph and lock policy

The graph has 34 non-project Git checkouts in the final Rebar3 lock and clean
default/test builds plus the project application. boss_db contributes the
largest transitive branch:
aleppo, ddb, dh_date, epgsql, erlando, erlmc, ets_cache, lager, medici,
mysql, poolboy, redo, tiny_pq, and uuid; ddb contributes ibrowse and jsx; the
web stack contributes cowboy, cowlib, and ranch. The test profile adds
boss_test.

The authoritative graph captures are:

- default: artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/dependency-tree.log;
- test: artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/dependency-tree-test.log;
- production: artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/dependency-tree-prod.log;
- application-level graph: artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/application-graph.tsv;
- application-level DOT graph: artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/application-graph.dot;
- checkout URLs and SHAs: artifacts/rebar3-migration-otp-21.3.8.24/evidence-final/resolved-checkouts.tsv.

Every manifest row compared VERIFIED in the final SHA report. erlmc is still
present in the lock and graph. It was not removed as a dependency; it is
excluded only from the explicit Relx startup closure because its historical
erlmc.app declares {mod,{erlmc,[]}} while the checkout does not provide the
required erlmc:start/2 callback. medici is also fetched and locked but is
excluded from the default release startup closure because it attempts an
external database connection during application start.

The migration changes dependency declarations only where needed for Rebar3
resolution and transport reproducibility:

1. Direct dependencies are full commit refs rather than abbreviated refs,
   moving branches, or version ranges.
2. Active legacy git:// transitive declarations are represented by exact
   HTTPS declarations at the same verified SHA (pmod_transform and
   stacktrace_compat).
3. mimetypes/master is pinned to
   ee98c7603c5effb525551913745e7458c360ed70, the verified historical revision.
4. No source revision was upgraded for convenience.

The old declarations, new declarations, SHA, and rationale are summarized in
docs/dependency-reproducibility.md and the TSV manifest. git:// strings
remaining in third-party source are catalogued historical declarations; they
are not used for the active Rebar3 lock resolution.

## The historical mimetypes build boundary

The locked mimetypes revision generates mimetypes_disp.beam and
mimetypes_map.beam only when the application is started. Rebar3 compilation
does not otherwise create them, and the dependency’s old app source does not
list them. A release assembled from only the default Rebar3 output therefore
fails in embedded mode with:

~~~text
undefined function mimetypes_disp:modules/0
~~~

The canonical Rebar3 configuration handles this without a dependency copy or
bootstrap script. The post-compile hook starts mimetypes, updates only its
generated .app metadata with the two generated module names, and fails the
build if that step fails. Relx overlays copy the same two BEAMs into releases.
The exact configuration is in rebar.config and skel/rebar3.config.

## Skeleton and generated applications

skel/chicagoboss.template is a native Rebar3 template index. The generator
creates:

- a generated rebar.config with exact dependency refs and profiles;
- a generated rebar.lock;
- app.app.src, config/sys.config, and config/vm.args;
- controllers, views, mail examples, filters, tags, routes, init scripts,
  static assets, and an empty ct/ directory.

The old copied Rebar, Makefile, shell bootstrap files, boss.config, and
custom plugin are not emitted. The application obtains Boss through its
generated dependency declaration. In the validation run the Boss URL was a
local bare mirror of the current feature branch because that branch is not
published; the ref was still the exact branch HEAD
aaf8fca66b54e14d6c3fa5297553785d830b1690. The template default remains the
immutable public 0.9.0 ref c7b9119b090cf5f4439e8b2b034a4541e746ab0c.
This local-mirror distinction is the reproducibility boundary for validating
unpublished branch changes.

The controller keeps the smallest OTP 21-compatible pmod shape:

~~~erlang
-module(generated_app_health_controller).
-export([new/1, index/3]).

new(_Req) ->
    {?MODULE, undefined}.

index('GET', [], _Instance) ->
    {output, "ok"};
index('HEAD', [], _Instance) ->
    {output, "ok"}.
~~~

The {Module, State} instance tuple works with ChicagoBoss’s existing
tuple_calls pmod adapter without using OTP 21-removed parameterized-module
syntax. Direct output avoids requiring src/view to be present in a production
Relx package.

Two independent template generations produced the same 18-file layout after
excluding the expected application-name substitutions; the comparison is in
generated-clean/template-repeat-file-diff.txt.

## Reproduction commands

The canonical clean workflow does not call bootstrap-deps.sh:

~~~sh
rm -rf deps ebin .rebar .eunit _build
export PATH="/Users/rlander/.asdf/installs/erlang/21.3.8.24/bin:$PATH"

./tools/rebar3 --version
./tools/rebar3 compile
./tools/rebar3 eunit
./tools/rebar3 ct
./tools/rebar3 release
./tools/rebar3 tar
~~~

The test suite is intentionally unchanged. The expected current result is:

~~~text
EUnit: 33 tests passed
Common Test: 1 failed
{noproc,{gen_server,call,[{global,boss_mq},{push,"test","Test Message"}]}}
~~~

The separate diagnostic that explicitly starts boss_mq belongs to the future
test-maintenance decision; this migration does not change
ct/boss_mq_SUITE.erl.

## Validation results

### Root project

| Command | Exit | Classification | Evidence |
| --- | ---: | --- | --- |
| clean normal-network rebar3 compile | 1 | TOOLING_NETWORK | root-clean/compile-normal-network-final.* |
| clean network-enabled rebar3 compile | 0 | pass | root-clean/compile-network-final.* |
| rebar3 eunit | 0 | pass, 33/33 | root-clean/eunit-final.* |
| unchanged rebar3 ct | 1 | TEST / stale setup | root-clean/ct-final-correct-path.* |
| rebar3 release | 0 | pass | root-clean/release-final.* |
| rebar3 tar | 0 | pass | root-clean/tar-final.* |
| final isolated clean checkout | 0 compile, 0 EUnit, 1 unchanged CT, 0 release, 0 tar | PASS except TEST | isolated-clean-final/ |

The release tarball SHA-256 is recorded in package-sha256.txt. The package
contains the generated mimetypes modules and no erlmc or medici application
directory in the explicit startup closure. The Makefile found under the OTP
crypto native-object directory is an Erlang runtime artifact, not a project
build entry point.

### Generated application

The generated app was created from an empty destination and compiled after
removing deps, ebin, .rebar, .eunit, and _build. The final results:

| Command or request | Result |
| --- | --- |
| generated rebar3 compile | exit 0 |
| generated rebar3 eunit | exit 0; no tests to run |
| generated rebar3 ct | exit 0; 0 tests |
| generated rebar3 release | exit 0 |
| generated rebar3 tar | exit 0 |
| GET /health | 200, body ok |
| HEAD /health | 200 |
| GET /static/chicago-boss.png | 200, non-empty body |
| GET /does-not-exist | 404 |
| release shutdown | exit 0 |

Raw compiler and runtime output is in
artifacts/rebar3-migration-otp-21.3.8.24/generated-clean/, especially
compile-verified.log, http-verified/runtime.log, and the HTTP headers and
bodies.

The final packaged-release rerun is in
`generated-clean/http-final-rerun/summary-network.txt` and its runtime log.
The first sandboxed attempt is retained separately in the same directory and
is classified `TOOLING_NETWORK` because the OS denied `inet_tcp` listener
registration; the approved rerun is the authoritative `PASS`.

## Warning and failure classification

The complete warning extraction is
artifacts/rebar3-migration-otp-21.3.8.24/compiler-warnings.tsv; raw logs are
never replaced by the filtered report. The warnings are historical and
include export_all, deprecated erlang:get_stacktrace/0,
crypto:rand_uniform/2, ssl:ssl_accept/*, unused variables/types, and Rebar
application metadata notices. They do not cause a compile failure.

The authoritative compile-count comparison is in
artifacts/rebar3-migration-otp-21.3.8.24/reports/warning-summary.tsv:

| Compile lane | Historical warning lines | Rebar3 warning lines |
| --- | ---: | ---: |
| root | 105 | 52 |
| generated application | 33 | 59 |

These are retained as observed counts. They are not treated as a regression
metric because the historical custom compiler and Rebar3 emit different
progress/profile output; the complete raw logs and normalized message lists
are retained under `reports/` for review.

| Classification | Current result |
| --- | --- |
| DEPENDENCY | none; all 34 non-project resolved SHAs verify |
| TOOLING_VERSION | none; Rebar3 3.15.2 runs on the target OTP |
| TOOLING_NETWORK | restricted sandbox cannot reach GitHub; approved HTTPS run succeeds |
| BUILD | none in final root/generated runs |
| TEST | unchanged root CT has the known one-case failure; EUnit passes |
| RUNTIME | generated packaged release HTTP matrix passes |
| PACKAGING | root and generated release/tar providers pass |

Transient harness failures caused by PATH values that omitted /bin are kept in
the artifact directory as tooling observations and are not counted as
application failures.

## Invariants and changed-file boundary

The final checks compare:

~~~sh
shasum -a 256 chicagoboss-baseline-otp-21.3.8.24.tar.gz
shasum -a 256 ct/boss_mq_SUITE.erl
git diff --exit-code -- ct/boss_mq_SUITE.erl
~~~

The baseline digest remains unchanged and the Common Test file has no diff.
The production compatibility files from the earlier remediation are not
edited by this Rebar3 migration. Migration source/configuration changes are
listed in artifacts/rebar3-migration-otp-21.3.8.24/changed-files.txt; the
complete unstaged state is deliberately left visible with git status --short
and git diff.

No files were staged or committed.

## Evidence index

~~~text
rebar.lock
config/dependency-lock.tsv
tools/rebar3-3.15.2
rebar3-migration-otp-21.3.8.24/
  evidence-final/                 version, graph, lock, app graph, SHA checks
  evidence-test-final/            test-profile checkout/SHA evidence
  root-clean/                     clean root logs and statuses
  generated-clean/                generation, clean build, tests, package, HTTP
  isolated-clean-final/           empty-input clean checkout rerun and classification
  compiler-warnings.tsv
  package-sha256.txt
~~~

The migration-only archive is created from this artifact directory after the
final invariant checks. It does not contain the immutable baseline archive.

Final migration archive:

~~~text
/private/tmp/chicagoboss-rebar3-migration-otp-21.3.8.24.tar.gz
SHA-256: bff9ba890934b4055099b000b5ad14f6ed45b31bb3b772657f6b578a92c0fda4
~~~
