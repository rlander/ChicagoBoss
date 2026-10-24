#!/usr/bin/env bash
set -euo pipefail

# Materialize the historical active dependency closure without using rebar's
# moving refs or any pre-existing local checkout.  The historical build path
# remains ./rebar and Makefile; this script only prepares deps/.

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
LOCK_FILE="${ROOT_DIR}/config/dependency-lock.tsv"
ERL_BIN="${ERL_BIN:-erl}"
EVIDENCE_DIR="${CB_DEPENDENCY_EVIDENCE:-${ROOT_DIR}/.dependency-evidence}"
MODE="bootstrap"
CLEAN=0

usage() {
    cat <<'USAGE'
Usage: scripts/bootstrap-deps.sh [--clean] [--verify-only]
                         [--evidence-dir DIR]

Materialize and verify the exact dependency revisions in
config/dependency-lock.tsv.  The default mode clones missing dependencies;
--verify-only never fetches and only checks existing deps/ checkouts.

--clean             Remove only this checkout's deps/, ebin/, .rebar/, and
                    .eunit/ before materializing dependencies.
--verify-only       Verify existing checkouts; do not clone or fetch.
--evidence-dir DIR  Write resolved SHA and runtime metadata under DIR.
USAGE
}

die() {
    echo "bootstrap-deps: $*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --clean)
            CLEAN=1
            ;;
        --verify-only)
            MODE="verify"
            ;;
        --evidence-dir)
            (($# >= 2)) || die "--evidence-dir requires a directory"
            EVIDENCE_DIR="$2"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
    shift
done

[[ -f "$LOCK_FILE" ]] || die "missing lock manifest: $LOCK_FILE"
[[ -x "$ROOT_DIR/rebar" ]] || die "historical ./rebar is missing or not executable"

if [[ "$ERL_BIN" == */* ]]; then
    [[ -x "$ERL_BIN" ]] || die "ERL_BIN is not executable: $ERL_BIN"
    ERL_REALPATH="$ERL_BIN"
else
    ERL_REALPATH="$(command -v "$ERL_BIN" || true)"
    [[ -n "$ERL_REALPATH" ]] || die "cannot resolve ERL_BIN=$ERL_BIN"
fi

OTP_RELEASE="$("$ERL_BIN" -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' 2>/dev/null)" \
    || die "unable to execute $ERL_BIN"
[[ "$OTP_RELEASE" == "21" ]] || die "expected OTP 21, got $OTP_RELEASE"

mkdir -p "$EVIDENCE_DIR"
if [[ "$CLEAN" -eq 1 && "$MODE" == "bootstrap" ]]; then
    # These are explicit, checkout-local paths.  Do not broaden this list.
    rm -rf "$ROOT_DIR/deps" "$ROOT_DIR/ebin" "$ROOT_DIR/.rebar" "$ROOT_DIR/.eunit"
fi

printf 'target_otp_label\t21.3.8.24\n' > "$EVIDENCE_DIR/runtime.tsv"
printf 'otp_release\t%s\n' "$OTP_RELEASE" >> "$EVIDENCE_DIR/runtime.tsv"
printf 'erl_bin\t%s\n' "$ERL_REALPATH" >> "$EVIDENCE_DIR/runtime.tsv"
printf 'root\t%s\n' "$ROOT_DIR" >> "$EVIDENCE_DIR/runtime.tsv"
printf 'mode\t%s\n' "$MODE" >> "$EVIDENCE_DIR/runtime.tsv"
printf 'clean_requested\t%s\n' "$CLEAN" >> "$EVIDENCE_DIR/runtime.tsv"
printf 'lock_file\t%s\n' "$LOCK_FILE" >> "$EVIDENCE_DIR/runtime.tsv"

mkdir -p "$ROOT_DIR/deps"
: > "$EVIDENCE_DIR/resolved-dependencies.tsv"
printf '# name\tremote\tdeclared_selector\texpected_sha\tactual_sha\tremote_origin\tstatus\n' \
    > "$EVIDENCE_DIR/resolved-dependencies.tsv"

TAB="$(printf '\t')"
count=0
while IFS="$TAB" read -r name remote selector expected class notes; do
    [[ -z "${name:-}" || "${name:0:1}" == "#" ]] && continue
    [[ -n "${remote:-}" && -n "${expected:-}" ]] || die "malformed lock row for $name"
    checkout="$ROOT_DIR/deps/$name"
    count=$((count + 1))

    if [[ "$MODE" == "bootstrap" && ! -d "$checkout" ]]; then
        echo "[bootstrap] cloning $name at $expected"
        GIT_TERMINAL_PROMPT=0 git clone --no-checkout "$remote" "$checkout"
        git -C "$checkout" checkout --detach --quiet "$expected"
    elif [[ "$MODE" == "bootstrap" && ! -d "$checkout/.git" ]]; then
        die "$checkout exists but is not a Git checkout; remove it or use --clean"
    fi

    [[ -d "$checkout/.git" ]] || die "missing checkout: $checkout"
    actual="$(git -C "$checkout" rev-parse HEAD)"
    origin="$(git -C "$checkout" config --get remote.origin.url || true)"
    if [[ "$actual" != "$expected" ]]; then
        printf '%s\t%s\t%s\t%s\t%s\t%s\tMISMATCH\n' \
            "$name" "$remote" "$selector" "$expected" "$actual" "$origin" \
            >> "$EVIDENCE_DIR/resolved-dependencies.tsv"
        die "$name resolved to $actual, expected $expected"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\tVERIFIED\n' \
        "$name" "$remote" "$selector" "$expected" "$actual" "$origin" \
        >> "$EVIDENCE_DIR/resolved-dependencies.tsv"
done < "$LOCK_FILE"

[[ "$count" -gt 0 ]] || die "lock manifest contained no dependencies"
printf 'dependency_count\t%s\n' "$count" >> "$EVIDENCE_DIR/runtime.tsv"
echo "[bootstrap] verified $count dependency checkouts under $ROOT_DIR/deps"
