#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

BASE_URL="${BASE_URL:-http://127.0.0.1:8001}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/boss-reference-http.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT INT TERM

get_status() {
    curl -s -o "$2" -w '%{http_code}' "$1"
}

post_status() {
    curl -s "$@"
}

login_headers="$TMP_ROOT/login.headers"
login_body="$TMP_ROOT/login.html"
status="$(curl -sD "$login_headers" -o "$login_body" -w '%{http_code}' "$BASE_URL/login")"
test "$status" = 200
grep -q 'csrfmiddlewaretoken' "$login_body"

csrf="$(sed -n 's/^set-cookie: csrf_token=\([^;]*\).*/\1/p' "$login_headers" | head -1)"
session="$(sed -n 's/^set-cookie: _boss_session=\([^;]*\).*/\1/p' "$login_headers" | head -1)"
cookie="csrf_token=$csrf; _boss_session=$session"

protected_body="$TMP_ROOT/protected.body"
protected_headers="$TMP_ROOT/protected.headers"
status="$(curl -sD "$protected_headers" -o "$protected_body" -w '%{http_code}' \
    -H "Cookie: $cookie" "$BASE_URL/projects/legacy-baseline/issues/new")"
test "$status" = 302
grep -qi 'location: /login' "$protected_headers"

missing_body="$TMP_ROOT/missing.body"
status="$(curl -s -o "$missing_body" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Cookie: $cookie" \
    --data 'username=owner&password=owner' "$BASE_URL/login")"
test "$status" = 403
grep -q 'CSRF validation failed' "$missing_body"

missing_cookie_body="$TMP_ROOT/missing-cookie.body"
status="$(curl -s -o "$missing_cookie_body" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Cookie: _boss_session=$session" \
    --data "username=owner&password=owner&csrfmiddlewaretoken=$csrf" \
    "$BASE_URL/login")"
test "$status" = 403

wrong_body="$TMP_ROOT/wrong-token.body"
status="$(curl -s -o "$wrong_body" -w '%{http_code}' -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Cookie: $cookie" \
    --data 'username=owner&password=owner&csrfmiddlewaretoken=wrong-token' \
    "$BASE_URL/login")"
test "$status" = 403

auth_headers="$TMP_ROOT/auth.headers"
status="$(curl -sD "$auth_headers" -o "$TMP_ROOT/auth.body" -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Cookie: $cookie" \
    --data "username=owner&password=owner&csrfmiddlewaretoken=$csrf" \
    -w '%{http_code}' "$BASE_URL/login")"
test "$status" = 302
grep -qi 'location: /' "$auth_headers"

api_body="$TMP_ROOT/api.json"
status="$(get_status "$BASE_URL/api/issues/boss_reference_issue-4" "$api_body")"
test "$status" = 200
grep -q '"labels":\["regression"\]' "$api_body"

create_headers="$TMP_ROOT/create.headers"
status="$(post_status -D "$create_headers" -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Cookie: $cookie" \
    --data "title=HTTP+smoke+issue&body=Created+by+the+repeatable+smoke+test&assignee_id=boss_reference_user-2&csrfmiddlewaretoken=$csrf" \
    -o "$TMP_ROOT/create.body" -w '%{http_code}' "$BASE_URL/projects/legacy-baseline/issues/new")"
test "$status" = 302
grep -qi 'location: /issues/boss_reference_issue-' "$create_headers"

logout_headers="$TMP_ROOT/logout.headers"
status="$(post_status -D "$logout_headers" -X POST \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H "Cookie: $cookie" \
    --data "csrfmiddlewaretoken=$csrf" \
    -o "$TMP_ROOT/logout.body" -w '%{http_code}' "$BASE_URL/logout")"
test "$status" = 302

status="$(curl -s -o "$TMP_ROOT/after-logout.body" -w '%{http_code}' \
    -H "Cookie: $cookie" "$BASE_URL/projects/legacy-baseline/issues/new")"
test "$status" = 302

echo "HTTP smoke passed"
