# Rebar3 integration for the legacy Chicago Boss compiler

This document records the implementation that replaces the historical Rebar 2
build orchestration while preserving Chicago Boss's programming model. It is
separate from the immutable historical baseline and from the future
`boss_mq_SUITE` maintenance decision.

## Compatibility objective

The migration target is Erlang/OTP 21.3.8.24 with Rebar3 3.15.2. The public
Chicago Boss source conventions remain unchanged, including:

```erlang
-module(myapp_health_controller, [Req]).
-export([index/2]).

index('GET', []) ->
    {output, "ok"}.
```

The native OTP 21 compiler rejects that module declaration when it is handed
directly to `compile:file/2`. The historical build did not do that. It parsed
the source with Chicago Boss's compiler, added route metadata, and then ran the
Boss pmod transforms before invoking `compile:forms/2`. The migration preserves
that boundary instead of converting controllers to an explicit-state API.

## Two compilation lanes

Rebar3 owns dependency resolution, ordinary framework compilation, test
discovery, profiles, and packaging. A small Rebar3 project plugin is registered
by `provider_hooks` and is executed after ordinary compilation:

```erlang
{project_plugins, [
    {chicago_boss_rebar3,
     {git_subdir, "https://github.com/rlander/ChicagoBoss.git",
                  {ref, "ac222b7"},
                  "priv/rebar3/chicago_boss_rebar3"}}
]}.

{provider_hooks, [
    {post, [{compile, chicago_boss_compile}]}
]}.
```

The two lanes are deliberately non-overlapping:

1. Rebar3 compiles `src/boss` and dependency applications using normal
   Rebar3 compiler providers. Root `src_dirs` excludes legacy app directories,
   so controllers, models, and views are not compiled once by `erlc` and again
   by Boss.
2. The `chicago_boss_compile` provider detects a legacy application by its
   `src/controller`, `src/model`, `src/view`, `src/mail`, or `src/lib` tree.
   It adds dependency and application code paths, stages the application's
   `priv/` files into the Rebar3 application output, and calls the existing
   `boss_load:load_all_modules_and_emit_app_file/2` exactly once.

The provider writes to the profile-specific Rebar3 output directory:

```erlang
OutDir = filename:join([
    rebar_dir:base_dir(State), "lib", atom_to_list(AppName), "ebin"
]).

boss_load:load_all_modules_and_emit_app_file(AppName, OutDir).
```

The generated `.app` file is therefore emitted from the same module lists and
compiler results that the historical loader used.

## Historical call chain retained

The provider reuses the existing call chain rather than duplicating it:

```text
chicago_boss_rebar3:do/1
  -> boss_load:load_all_modules_and_emit_app_file/2
     -> boss_load:load_web_controllers/2
        -> boss_compiler_adapter_erlang:compile_controller/2
           -> boss_controller_compiler:compile/2
              -> boss_compiler:compile/2
                 -> boss_db_pmod_pt and boss_db_pt
                    -> compile:forms/2
```

`boss_controller_compiler:add_routes_to_forms/1` runs before the pmod
transformation. For every action clause it adds `_routes/0` and exports it.
The pmod transform turns this into `_routes/1`, which is the interface read by
`boss_controller_lib:convert_params_to_tokens/3` for reverse routing and URL
variable extraction.

Models follow the existing model-manager route:

```text
boss_load
  -> boss_model_manager_boss_db:compile/2
     -> boss_record_compiler:compile/2
        -> boss_compiler:compile/2
           -> boss_db_pmod_pt and boss_db_pt
              -> compile:forms/2
```

Views continue through `boss_template_adapter_erlydtl` and `erlydtl:compile`
with the historical helper, translator, dependency, and output-directory
options. No generated view source is compiled by the standard Rebar3 lane.

## OTP 21 transform handling

The root framework has no raw parameterized application controllers in its
ordinary `src/boss` tree, so its ordinary Rebar3 options use the upstream
`pmod_pt` transform where needed:

```erlang
{erl_opts, [
    debug_info,
    {parse_transform, lager_transform},
    {parse_transform, cut},
    {parse_transform, do},
    {parse_transform, import_as},
    {parse_transform, pmod_pt}
]}.
```

The `boss_db` dependency must retain its historical transform sequence. Rebar3
overrides replace, rather than merge, `erl_opts`, so the override includes all
original transforms and the compatibility wrapper:

```erlang
{override, boss_db, [{erl_opts, [
    debug_info,
    warn_unused_vars,
    warn_unused_import,
    warn_exported_vars,
    {parse_transform, lager_transform},
    {parse_transform, cut},
    {parse_transform, do},
    {parse_transform, import_as},
    {parse_transform, chicago_boss_pmod_pt}
]}]}
```

`chicago_boss_pmod_pt` is a two-step compatibility transform:

```erlang
-module(chicago_boss_pmod_pt).

parse_transform(Forms, Options) ->
    Rewritten = cut:parse_transform(Forms, Options),
    pmod_pt:parse_transform(Rewritten, Options).
```

The order is required because the old `cut` syntax must be rewritten before
the pmod transform sees the forms. The wrapper is used only where its module
is available; it is not double-applied to forms already transformed by the
Boss compiler.

## Generated applications

The skeleton's `src/controller/health_controller.erl` remains the legacy
parameterized module. Its Rebar3 configuration uses the same project provider
and excludes `src/controller`, `src/model`, and `src/view` from ordinary
compilation:

```erlang
{src_dirs, ["src/boss"]}.
{provider_hooks, [{post, [{compile, chicago_boss_compile}]}]}.
```

`src/<application>.app.src` remains in the historical location because
`boss_load:dot_app_src/1` reads that path. The provider stages `priv/` into the
application output, which keeps routes, static files, init scripts, and
templates available to `code:priv_dir/1` and the legacy runtime path.

The generated application resolves its own exact dependency graph. It does not
copy a prebuilt `deps/` tree, use the bootstrap investigation script, or
rewrite the controller syntax.

## Integration coverage

`test/boss_rebar3_legacy_compatibility_test.erl` compiles
`fixtures/legacy_app` through `boss_load` and exercises:

- a `[Req]` controller with GET actions and action-dependent request state;
- a `[Req, SessionID]` controller;
- `before_`, `after_`, and `config` hooks;
- `_routes/1`, route-variable extraction, dynamic route matching, and reverse
  routing;
- a parameterized BossRecord model, attributes, mock database save, and find;
- an ErlyDTL template render with a variable.

The fixture is intentionally broader than the generated `/health` smoke
endpoint. It verifies the interfaces that would regress if Rebar3 bypassed the
historical compiler.

On OTP 21.3.8.24 with the pinned local validation mirror, the clean results
are:

```text
rebar3 compile  PASS
rebar3 eunit    PASS (38 tests, including the legacy compatibility fixture)
```

The unchanged Common Test suite remains a separate test-maintenance issue. Its
known `boss_mq_SUITE` setup/result-shape failure is not changed by this work.

## Reproducibility boundary and remaining gaps

- The canonical plugin declaration is a pinned HTTPS Git-subdirectory
  dependency. The feature-branch plugin commit must be published to the
  configured remote before an external clone can fetch that exact ref. Local
  clean validation used a temporary bare Git mirror solely to test the
  unpushed branch; it did not populate `deps/` manually.
- Only OTP 21.3.8.24 is validated here. OTP 21.2 was not installed or
  investigated. OTP 29 remains unvalidated and must not be advertised as
  supported until the full compile/test/runtime matrix passes there.
- Development automatic reload, optional Elixir/LFE compiler paths, and the
  complete historical `boss.config` surface still have documented migration
  boundaries. They are not silently represented as equivalent.
- Packaging and generated-app HTTP checks remain final validation gates after
  the provider and skeleton changes are published together.

The immutable baseline archive is an input to comparison only and is not
modified by this integration.
