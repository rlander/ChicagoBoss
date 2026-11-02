# Rebar3 development auto-reload implementation report

Date: 2026-10-28

This report records the implementation and validation of development-mode
automatic reload on the Rebar3 branch. It is separate from the immutable
historical baseline and from the deferred `boss_mq_SUITE` maintenance work.

## Result

Development reload is restored for ChicagoBoss applications started with:

```sh
rebar3 compile
rebar3 shell
```

The supported validation toolchain is Erlang/OTP 21.3.8.24 and Rebar3 3.15.2.
The current branch's production compatibility behavior remains intact.

The implementation combines three pieces:

1. `config/sys.dev.config` sets `boss.developing_app` for a generated or
   reference application.
2. `boss_app` starts the historical MochiWeb `reloader` when that setting is
   present, before starting the Boss supervisor.
3. `boss_files_util:ebin_dir/0` prefers the active Rebar3 application ebin
   directory, while retaining the historical root `ebin/` fallback.
4. `boss_env` requires both the loaded reloader module and an explicit
   `boss.developing_app`, so embedded production releases are not mislabeled
   development merely because their boot script loads MochiWeb modules.
5. Rebar3's escript pseudo-paths are handled by the tracked
   `priv/rebar3/reloader.erl` compatibility copy, which ignores only the
   expected `enotdir` result while preserving other watcher errors.

Rebar3 3.15.2 accepts the shell `config` setting but does not consume its
`vm_args` setting. `config/vm.dev.args` is therefore supplied for alternate
launchers and documentation; the canonical `rebar3 shell` path starts the
reloader through `boss_app`.

## Changed files

| File | Reason |
| --- | --- |
| `src/boss/boss_app.erl` | Start MochiWeb's reloader only when `boss.developing_app` is explicitly configured. Production startup remains unchanged. |
| `src/boss/boss_env.erl` | Require both reloader presence and explicit development-app configuration before selecting development mode; this protects embedded production releases. |
| `src/boss/boss_files_util.erl` | Direct dynamic compilation and freshness checks to `code:lib_dir(App, ebin)` under Rebar3, with the historical root-ebin fallback. |
| `skel/config/sys.dev.config` | Development-only application environment, including `boss.developing_app`. |
| `skel/config/vm.dev.args` | Development node name, cookie, and historical `-s reloader` alternate-launcher arguments. |
| `skel/rebar3.config` | Select the development sys/vm files for `rebar3 shell`. |
| `skel/chicagoboss.template` | Emit the development files in newly generated applications. |
| `priv/rebar3/reloader.erl` | Preserve the historical watcher while ignoring Rebar3 escript pseudo-paths that return `enotdir`. |
| `skel/priv/rebar3/reloader.erl` | Include the same watcher compatibility copy in generated applications. |
| `rebar.config`, `boss_reference/rebar.config`, `skel/rebar3.config` | Compile the tracked compatibility copy over MochiWeb during the Rebar3 compile hook. |
| `boss_reference/config/sys.dev.config` | Reference-application development environment. |
| `boss_reference/config/vm.dev.args` | Reference-application development VM arguments. |
| `boss_reference/rebar.config` | Select the reference application's development files for its shell. |
| `README.md` | Document the Rebar3 development-shell workflow and production boundary. |
| `docs/rebar3-compatibility-gaps.md` | Record restored auto-reload behavior and remaining explicit-reload/tooling boundaries. |
| `CHANGELOG.md` | Record the user-visible compatibility change. |

No dependency revision was changed. `ct/boss_mq_SUITE.erl` was not modified.
The baseline archive was not modified or overwritten.

## Legacy behavior reproduced

The historical `priv/rebar/boss_rebar.erl:start_dev_cmd/3` emitted a VM
command containing the equivalent of:

```text
-pa <dependency-ebin> ...
-pa <application-ebin>
-boss developing_app <application>
-s reloader
-s lager
-s boss
```

The locked MochiWeb checkout is SHA
`53a9607510b7ae4c662305fa978c73edf06c4cb2`. Its `reloader` is a historical
gen_server with a one-second polling interval. It scans loaded modules and
reloads changed BEAM files; it does not compile source files. ChicagoBoss's
development request loaders continue to compile controllers, models,
libraries, and views from source.

The relevant reloader API was inspected directly:

```erlang
reloader:module_info(exports).
%% includes start/0 and start_link/0
```

`boss_env` detects development mode only when both the `reloader` module is
loaded and `boss.developing_app` is configured, and caches the result in the
process dictionary. Starting the reloader from the Boss application callback
avoids the startup-order race that would occur if a request process cached
production mode first. The two-signal predicate also matters for embedded
Relx releases: those boots can load MochiWeb's module list without starting
the reloader process.

## Validation evidence

The complete run evidence was saved outside the checkout at:

```text
/private/tmp/chicagoboss-auto-reload-2026-10-28.BVyY3j
```

The generated-app evidence uses this isolated temporary application:

```text
/private/tmp/chicagoboss-auto-reload-generated-current2.LWV1Fg/myapp
```

### Root application

| Command | Result |
| --- | --- |
| `tools/rebar3 compile` | PASS |
| `tools/rebar3 eunit` | PASS; 38 tests passed |
| `tools/rebar3 ct` | Known test failure only: `boss_mq_SUITE:test_poll` fails during setup with `noproc`; suite unchanged. |
| `tools/rebar3 release` | PASS |
| `tools/rebar3 tar` | PASS |

The Common Test failure is classified as a pre-existing test failure, not a
reload implementation failure. The production `boss_mq_SUITE` setup still
does not start the expected process and its historical poll tuple expectation
remains deferred to a separate test-maintenance decision.

### `boss_reference`

`boss_reference` was repeatedly used as the integration reference. Its
Rebar3 compile, EUnit, Common Test, release, and tar checks passed. The live
development run used the current working-tree Boss beams in an isolated build
directory; no tracked dependency declaration was changed to make that local
overlay appear reproducible.

The live reference checks established:

- `reloader` had a live PID;
- `boss_env:boss_env()` returned `development`;
- `boss.developing_app` was `boss_reference`;
- `boss_files_util:ebin_dir/0` resolved to the reference application's
  Rebar3 ebin directory;
- controller, view, and library edits became observable without restarting
  the VM;
- an invalid source edit produced a failed response while the VM remained
  alive, and restoring valid source recovered the response;
- the existing parameterized controllers, hooks, reverse routes, metadata,
  BossRecord models, mock database behavior, and ErlyDTL coverage remained
  covered by the passing reference tests.

### Fresh generated application

The skeleton was generated in a clean temporary directory using Rebar3's
global template directory and the checked-in `skel/` contents. The generated
application received `sys.dev.config` and `vm.dev.args`; it contained no
copied `deps/` or root `ebin/` directory.

With its exact published dependency revisions, the generated app passed:

```text
rebar3 compile   PASS
rebar3 eunit     PASS (no generated tests)
rebar3 ct        PASS (0 tests)
rebar3 release   PASS
rebar3 tar       PASS
```

The generated dependency graph included `erlmc`; it was not removed. The
resolved graph and SHAs are in `generated-current2-deps-tree.log`,
`generated-current2-dependency-shas.txt`, and `rebar.lock` in the temporary
application.

The published Boss revision used by that clean generated checkout predates the
working-tree reloader patch, so its first unmodified shell boot correctly
reported production mode and no reloader. For the development behavior test,
only the current working-tree Boss beams were overlaid into the isolated
generated application's build directory. With that explicit overlay:

- development mode and a live reloader were observed;
- `GET /health` returned 200 and `ok`;
- `HEAD /health` returned 200;
- the static PNG returned 200 and 55,735 bytes;
- an unknown route returned 404;
- changing the health controller to return `reloaded` changed the response
  after the polling interval without restarting the VM.

This is a deliberate publication boundary: an external clean checkout can
compile and package from the published pinned Boss revision, but it cannot
exercise the new callback until the feature-branch Boss revision is published
and the generated application's Boss ref is updated to that immutable SHA.

Route, translation, and init-script refresh are not claimed as generic
automatic filesystem behavior. The historical explicit APIs remain the
supported boundary; route reload was separately probed through
`boss_web:reload_routes/0` and is documented as explicit/request-driven where
the application's dispatcher requires it.

## Warnings and logs

Compiler output was preserved in the evidence directory. Warnings are legacy
dependency/source warnings, including deprecated OTP APIs (`ssl_accept/1,2,3`,
`crypto:rand_uniform/1,2`, `random:*`, and `erlang:get_stacktrace/0`),
`export_all`, unused imports/variables, and the known `erlmc` binary warning.
They do not cause the compile commands to fail.

Before the compatibility overlay, the live development log contained repeated
`enotdir` messages for Rebar3 host modules whose escript pseudo-paths look like
`tools/rebar3/rebar/ebin/*.beam`. The overlay was then validated in a live
development shell for more than one polling interval: `reloader` remained
alive, `boss_env:boss_env()` returned `development`, and no new `enotdir`
messages were emitted. The original MochiWeb revision and dependency lock
remain unchanged.

## Failure classification

| Classification | Finding | Status |
| --- | --- | --- |
| Dependency | No dependency revision changes were needed. The generated clean graph resolved the locked historical closure, including `erlmc`. | PASS |
| Tooling/version | Rebar3 3.15.2 ignores shell `vm_args`; the callback is the canonical startup bridge. Rebar3 host paths are filtered by the tracked watcher compatibility overlay. | PASS; remaining `vm_args` behavior documented |
| Network/publication | A clean external generated checkout resolves the published Boss ref, but the current feature-branch Boss patch must be published before external dev-shell parity is possible. | Publication boundary |
| Build | Root and generated Rebar3 compile passed on OTP 21.3.8.24. | PASS |
| Test | Root EUnit passed. Root CT retains only the known unchanged `boss_mq` setup failure; generated/reference suites passed. | Classified separately |
| Runtime | Development mode, live reload, HTTP smoke behavior, invalid-source recovery, and a quiet watcher interval passed with current Boss beams. | PASS |
| Packaging | Root and generated release/tar commands passed. | PASS |

The final production-boundary rerun also booted the generated release with the
current Boss beams overlaid and logged `Starting Boss in production mode...`.
The root release remains a historical artifact with no Simple Bridge backend
configured, so its independent foreground boot still exits with the existing
`no backend defined` configuration error; this is a release-configuration
failure, not a reloader failure. The generated production release is the
runtime boundary check for this change.

## Invariants

Before and after the implementation:

```text
baseline archive SHA-256:
cf123ea5ec3b0f28a54b99e7a6c38bb6a7d6e4f3a19c6ffb01a1663cc59a254d

ct/boss_mq_SUITE.erl SHA-256:
71cb1714af3fdc2ec80dba53145acec83dbd37963b9fa9984f4cf85905f41e63
```

OTP 21.2 was not installed or investigated. No dependency checkout was
manually copied into the generated source tree; the local Boss-beam overlay
was confined to an isolated temporary validation directory and is explicitly
identified above.
