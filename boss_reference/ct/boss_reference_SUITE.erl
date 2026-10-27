-module(boss_reference_SUITE).
-compile(export_all).

all() -> [compiled_reference_application].

compiled_reference_application(_Config) ->
    Beam = code:which(boss_reference_fixtures),
    true = Beam =/= non_existing,
    ok = application:load(boss_reference),
    ok.
