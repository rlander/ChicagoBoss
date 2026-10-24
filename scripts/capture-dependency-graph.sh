#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
OUTPUT_DIR="${1:-${ROOT_DIR}/.dependency-evidence}"
BUILD_LOG="${2:-}"
ERL_BIN="${ERL_BIN:-erl}"

mkdir -p "$OUTPUT_DIR"
cd "$ROOT_DIR"

git rev-parse HEAD > "$OUTPUT_DIR/chicagoboss-commit.txt"
git status --short > "$OUTPUT_DIR/worktree-status.txt"

if [[ -n "$BUILD_LOG" && -f "$BUILD_LOG" ]]; then
    # Keep the complete build log untouched; this is a filtered companion.
    rg -n -i '(^|[^[:alnum:]])warning([^[:alnum:]]|:)' "$BUILD_LOG" \
        > "$OUTPUT_DIR/compiler-warnings.txt" || true
else
    : > "$OUTPUT_DIR/compiler-warnings.txt"
fi

GRAPH_TEXT="$OUTPUT_DIR/application-dependencies.txt" \
GRAPH_DOT="$OUTPUT_DIR/application-dependencies.dot" \
"$ERL_BIN" -noshell -eval '
    Text = os:getenv("GRAPH_TEXT"),
    Dot = os:getenv("GRAPH_DOT"),
    {ok, TextFile} = file:open(Text, [write]),
    {ok, DotFile} = file:open(Dot, [write]),
    io:format(DotFile, "digraph applications {~n"),
    Files = lists:sort(filelib:wildcard("ebin/*.app") ++ filelib:wildcard("deps/*/ebin/*.app")),
    lists:foreach(fun(File) ->
        case file:consult(File) of
            {ok, [{application, App, Props}]} ->
                Applications = proplists:get_value(applications, Props, []),
                Included = proplists:get_value(included_applications, Props, []),
                io:format(TextFile, "~s~t~p~tapplications=~p~tincluded=~p~n",
                          [File, App, Applications, Included]),
                lists:foreach(fun(Dep) ->
                    io:format(DotFile, "  \"~p\" -> \"~p\";~n", [App, Dep])
                end, Applications ++ Included);
            Other ->
                io:format(TextFile, "~s~tUNPARSED~t~p~n", [File, Other])
        end
    end, Files),
    io:format(DotFile, "}~n"),
    file:close(TextFile),
    file:close(DotFile),
    halt().
'

echo "captured application graph and warning report in $OUTPUT_DIR"
