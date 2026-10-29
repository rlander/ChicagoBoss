# Rebar3 compatibility gaps and migration notes

This document records behavior that changed, was removed, or still needs a
separate follow-up after the Rebar3 migration. It is deliberately separate
from the clean-build evidence in `docs/rebar3-migration.md`.


Supported baseline
------------------

The migration is maintained and validated only with:

```text
Erlang/OTP 21.3.8.24
Rebar3 3.15.2
```

OTP 21.2 was not installed or investigated. The dependency closure is locked
in `rebar.lock`; the human-readable dependency and selector manifest is
`config/dependency-lock.tsv`.


Development startup and automatic reload
----------------------------------------

The historical generated application used `init-dev.sh`, which invoked the
custom Rebar plugin to produce an Erlang command containing:

```text
-s reloader
-boss developing_app <application>
```

The Rebar3 skeleton now starts development applications with:

```sh
rebar3 compile
rebar3 shell
```

The development shell selects `config/sys.dev.config`, which sets
`boss.developing_app`. `boss_app` starts the locked MochiWeb `reloader` before
the Boss supervisor starts. `boss_files_util:ebin_dir/0` resolves the active
Rebar3 application ebin directory and retains the historical root `ebin/`
fallback. `boss_env` selects development mode only when both the reloader
module and an explicit `boss.developing_app` are present; this matters for
embedded releases, which can load MochiWeb's module list without starting the
reloader. The legacy request-time loaders continue to compile and load
controllers, models, libraries, and views.

Rebar3 3.15.2 does not apply the `vm_args` key from the shell configuration,
so `config/vm.dev.args` is retained for alternate launchers and is not the
canonical mechanism used by `rebar3 shell`. Rebar3 itself does not compile
source on every filesystem change; ChicagoBoss's historical request-time
loaders and MochiWeb's BEAM reloader provide the development behavior.

Production releases continue to use `config/sys.config` and `config/vm.args`
without `developing_app` or `-s reloader`.

The current Rebar3 shell also loads Rebar3's host modules in the same VM. The
historical reloader reports repeated `enotdir` file-info messages for those
host-module pseudo-paths; this is a tooling-log boundary and does not prevent
application reload. It must remain classified separately from application
compile or runtime failures.

The unchanged Common Test suite remains a separate maintenance issue. Its
`boss_mq` setup and historical `poll/2` tuple expectation are not changed by
the reload implementation.

Before development reload was restored, changes required:

```sh
rebar3 compile
# restart rebar3 shell
```

The dev-only configuration now starts MochiWeb's `reloader`, sets the
developing application, and leaves production releases unaffected. The
historical reloader watches loaded BEAM files; ChicagoBoss's request-time
loaders remain responsible for source compilation. Route, translation, and
init-script refresh APIs remain explicit boundaries rather than promises of
automatic filesystem reload.


Controller source compatibility
-------------------------------

The historical controller convention used Erlang parameterized modules:

```erlang
-module(myapp_controller, [Req]).

index('GET', []) ->
    {output, "ok"}.
```

The generated Rebar3 controller remains a parameterized module. The Rebar3
project provider invokes the historical Chicago Boss compiler after ordinary
framework/dependency compilation:

```text
chicago_boss_compile
  -> boss_load:load_all_modules_and_emit_app_file/2
     -> boss_controller_compiler:compile/2
        -> boss_compiler:compile/2
           -> boss_db_pmod_pt and boss_db_pt
```

OTP 21.3.8.24 rejects raw parameterized-module syntax in the native compiler,
but this is an OTP compiler limitation rather than a Rebar3 limitation. The
historical compiler adds `_routes/0` before applying the pmod transform, and
the unchanged `boss_controller_adapter_pmod` consumes the resulting
`_routes/1`, `new/1`, and action exports. Existing applications therefore do
not need to migrate to an explicit `new/1` or state-argument controller API.


Configuration migration
-----------------------

`boss.config` was both a runtime configuration file and an input to the custom
Rebar plugin. It also contained dependency paths such as `./deps/boss`. It is
not used by the Rebar3 workflow.

The replacements are:

| Historical concern | Rebar3 location |
| --- | --- |
| Git dependencies and local dependency paths | `rebar.config`, `rebar.lock` |
| Application environment | `config/sys.config` |
| Node name, cookie, and VM flags | `config/vm.args` |
| Development startup | `rebar3 shell` |
| Production startup | Relx release script |
| Release assembly | `rebar3 release` |
| Distribution archive | `rebar3 tar` |

The generated `sys.config` currently carries the minimum working settings:

- application list and assumed locale;
- mock database and session adapters;
- session enablement and logging enablement;
- Cowboy server, bind address, port, document root, and static path;
- application path, base URL, static prefix, controller modules, and static files.

The following historical settings are not explicitly represented in the
generated template and must be added manually when needed:

- VM cookie, node name, short name, and maximum process count;
- controller filter configuration and custom compiler options;
- cache adapter, cache servers, expiry, and enablement;
- database host, port, credentials, database name, SSL, sharding, and adapter
  configuration;
- mail driver, SMTP relay settings, and incoming SMTP server settings;
- master-node and websocket-timeout settings;
- session key, expiry, cookie security, Mnesia nodes, and session domain;
- custom template tag/filter modules and automatic escaping configuration;
- SSL server configuration and multiline log formatting;
- Lager file handlers, log root, and colored logging;
- TinyMQ settings such as `max_age`;
- Simple Bridge upload limits, in-memory upload limits, and scratch directory;
- application domains and documentation prefix.

Many of these entries were commented examples rather than active defaults in
the historical skeleton. They are listed here so their absence is visible and
does not look like an accidental loss of functionality.


Legacy command mapping
----------------------

The main build lifecycle has direct Rebar3 commands:

| Historical command | Rebar3 command | Status |
| --- | --- | --- |
| `make` / `make compile` | `rebar3 compile` | Supported |
| `make get-deps` | dependency resolution during `rebar3 compile` | Supported |
| `make test` / Rebar EUnit | `rebar3 eunit` | Supported |
| Rebar Common Test | `rebar3 ct` | Supported with known suite failure |
| `make app PROJECT=x` | `rebar3 new chicagoboss x` | Supported, with reproducible dependency behavior |
| `start-dev` | `rebar3 shell` | Supported; development auto-reload restored |
| `start-fg` | release `bin/<app> foreground` | Supported |
| `start` / `stop` / `restart` | release `bin/<app> start/stop/restart` | Supported |
| `attach` | release `bin/<app> remote_console` | Supported |
| `reload` | no direct equivalent | Requires a release-upgrade or dev-reloader design |

The following historical targets are not migrated as dedicated Rebar3
providers in this branch:

- `make edoc`;
- `make dialyze` and `make plt`;
- `make test_session_cache`, `test_session_mnesia`, and `test_session_mock`;
- `make rebarize`;
- `make rebar_src`;
- the custom `boss test_functional` command;
- the old Windows batch wrappers.

These can be added later as standard Rebar3 providers or documented commands,
but they are not silently claimed to have one-to-one replacements.


Generated application differences
----------------------------------

Generated applications no longer copy the current ChicagoBoss checkout or a
manually populated `deps/` directory. They receive an exact Git dependency and
resolve their own dependency graph through Rebar3.

The generated application also differs from the historical skeleton in these
ways:

- configuration is split between `config/sys.config` and `config/vm.args`;
- the default HTTP port is `18001` rather than `8001`;
- a `/health` route is included for deterministic smoke testing;
- a `ct/` directory is created but contains no test suites yet;
- old Makefile, Rebar 2, plugin, `boss.config`, `init.sh`, `init-dev.sh`, and
  batch-wrapper files are not emitted;
- release packaging is performed by Relx through Rebar3.


MIME type handling
------------------

The current migration retains the historical `mimetypes` dependency. That
dependency generates `mimetypes_disp.beam` and `mimetypes_map.beam` when its
application starts, while its historical `.app` file does not list those
modules. The Rebar3 configuration therefore contains a post-compile hook and
a release overlay to materialize and package them.

If ChicagoBoss formally supports Cowboy only, the dependency can be removed in
a follow-up by:

1. removing the explicit `mimetypes` start/stop calls from `src/boss/boss.erl`;
2. removing the dependency and lock entry;
3. deleting the post-compile hook and Relx overlay;
4. relying on Cowboy's `cow_mimetypes` implementation;
5. testing MIME types for all supported static-file extensions and packaged
   releases;
6. documenting that the Inets backend no longer receives the historical broad
   MIME map.

This is a source and backend-support decision, not only a dependency cleanup.


`erlmc` and `medici`
--------------------

Both dependencies remain in the locked historical `boss_db` closure.

`erlmc` compiles, but its application descriptor contains:

```erlang
{mod, {erlmc, []}}
```

without an `erlmc:start/2` callback. It is therefore excluded from the default
release startup closure. A future Memcached-support change can either remove
the invalid application callback declaration or add a proper OTP application
wrapper and pin a repaired fork.

`medici` has a valid OTP application callback, but its supervisor opens
connections to an external Tokyo Tyrant service during startup. It is excluded
from the default release so a normal generated application does not require
that external service. A Tokyo Tyrant application must configure and start it
explicitly, or provide a future lazy-start/optional-backend change.

Neither dependency requires a fork for the default mock/Cowboy generated
application.


Testing boundary
----------------

The root EUnit lane passes in the recorded OTP 21.3.8.24 validation. The
unchanged Common Test suite currently fails because `boss_mq_SUITE` does not
start `boss_mq` before calling it, and its expected `poll/2` result shape is
stale. This is retained as a test-maintenance issue and is separate from the
production compatibility and Rebar3 migration changes.

The generated skeleton currently contains no Common Test suites. Add suites
under `ct/` and run them with:

```sh
rebar3 ct
```


Evidence and artifacts
----------------------

`artifacts/` and `.dependency-evidence/` contain reproducibility logs,
dependency graphs, compiler warnings, runtime output, and intermediate
validation results. They are not required inputs to compile, test, run, or
package the application. They may be archived externally or removed after the
baseline review, but documentation links to retained evidence should be
updated if the directories are deleted.
