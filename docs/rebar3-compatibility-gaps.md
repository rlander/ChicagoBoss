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

The current skeleton does not yet add `-s reloader` to a development-only VM
arguments file or set `boss:developing_app`. Rebar3 itself does not watch files.
Consequently, `rebar3 shell` starts the application in the foreground, but
automatic source reload is not currently equivalent to the old `init-dev.sh`
workflow. Changes normally require:

```sh
rebar3 compile
# restart rebar3 shell
```

A future development-mode change should add and test a dev-only configuration
that starts MochiWeb's `reloader`, sets the developing application, and leaves
production releases unaffected.


Controller source compatibility
-------------------------------

The historical controller convention used Erlang parameterized modules:

```erlang
-module(myapp_controller, [Req]).

index('GET', []) ->
    {output, "ok"}.
```

The generated Rebar3 controller uses an ordinary OTP 21 module and an explicit
instance constructor:

```erlang
-module(myapp_health_controller).
-export([new/1, index/3]).

new(Req) ->
    {?MODULE, Req}.

index('GET', [], Req) ->
    {output, sbw:query_param("message", Req)}.
```

The production adapter contains `-compile(tuple_calls)`. This allows the
adapter to invoke an instance represented as `{Module, State}` while retaining
the historical controller calling convention. The request is stored as the
instance state by `new/1` and is passed to the action as its final argument.

The health controller stores `undefined` because it does not need request data.
Existing applications using parameterized-module syntax need explicit
validation with the Rebar3 generated application. They may require the
`pmod_pt` compatibility transform or a migration to the explicit `new/1` and
action-arity form.


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
| `start-dev` | `rebar3 shell` | Supported, without automatic reload parity |
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

