# OTP 26 packaging remediation

## Finding

OTP 26 adds the `socket` module to the `kernel` application. The historical
locked `gen_smtp` revision, 0.11.0 (`2ea8bb995adf32102f523cef93ae98e287ac77d1`),
also shipped a top-level `socket` module. Compilation could succeed, but Relx
refused to assemble a release with:

```text
Duplicated modules: socket specified in kernel and gen_smtp
```

The module is part of gen_smtp's SMTP implementation, so excluding it from the
release would not be a safe fix. Upstream gen_smtp 0.14.0 renamed that private
module to `smtp_socket` while retaining the `gen_smtp_client` and
`gen_smtp_server` APIs used by ChicagoBoss. The exact verified revision is
`49a907102021c836fcbc7db0e43f71133b77452f`.

## Minimal change

The following dependency declarations were changed from the historical
`Vagabond/gen_smtp` 0.11.0 revision to the upstream `gen-smtp/gen_smtp` 0.14.0
revision:

```erlang
{gen_smtp, {git, "https://github.com/gen-smtp/gen_smtp.git",
                    {ref, "49a907102021c836fcbc7db0e43f71133b77452f"}}}
```

Changed files:

- `rebar.config`
- `rebar.lock`
- `boss_reference/rebar.config`
- `boss_reference/rebar.lock`
- `skel/rebar3.config`
- `config/dependency-lock.tsv`

No ChicagoBoss production source, generated application source, or Common Test
file was changed. The immutable OTP 21 baseline archive and its historical
dependency results were not modified.

The lock and human-readable manifest now agree on the remote, tag, and exact
commit. The dependency is marked immutable in `config/dependency-lock.tsv`.
The upstream release history identifies 0.14.0 as the first release with the
private socket-module rename; the exact commit is recorded in the lock files.

## Validation on OTP 26.2.5.21

All checks used the checked-in Rebar3 3.22.1 executable and explicitly selected
`/Users/rlander/.asdf/installs/erlang/26.2.5.21/bin`.

| Check | Result |
| --- | --- |
| Root clean `rebar3 compile` | PASS |
| Root `rebar3 eunit` | PASS, 38 tests |
| Root unchanged `rebar3 ct` | One known test failure only: `boss_mq_SUITE:test_poll` |
| Root `rebar3 release` | PASS |
| Root `rebar3 tar` | PASS |
| Reference clean `rebar3 compile` | PASS |
| Reference `rebar3 eunit` | PASS, 7 tests |
| Reference `rebar3 ct` | PASS, 1 test |
| Reference `rebar3 release` | PASS |
| Reference `rebar3 tar` | PASS |
| Reference shell and HTTP smoke | PASS; all application smoke requests succeeded |

The root Common Test result remains the pre-existing test-maintenance issue:

```text
{noproc,{gen_server,call,[{global,boss_mq},{push,"test","Test Message"}]}}
```

It is not a dependency or packaging failure, and `ct/boss_mq_SUITE.erl` was
left unchanged.

The compiler and Relx still report historical warnings and optional-code
diagnostics, including removed `get_stacktrace/0`, `crypto:hmac/3`, and
`ssl:ssl_accept/3` calls. They are non-blocking modernization warnings. The
previous fatal duplicate-module diagnostic is absent after the pin.

The captured command logs for this remediation were written outside the
repository under `/private/tmp` with the `otp26-gensmtp014` prefix. They are
not part of the immutable baseline archive.

## Reproduction

From a clean checkout with OTP 26.2.5.21:

```sh
rm -rf _build deps ebin .rebar .eunit
PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ./tools/rebar3 compile
PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ./tools/rebar3 eunit
PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ./tools/rebar3 ct
PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ./tools/rebar3 release
PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ./tools/rebar3 tar

rm -rf boss_reference/_build
(cd boss_reference && \
  PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ../tools/rebar3 compile && \
  PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ../tools/rebar3 eunit && \
  PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ../tools/rebar3 ct && \
  PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ../tools/rebar3 release && \
  PATH="$HOME/.asdf/installs/erlang/26.2.5.21/bin:$PATH" ../tools/rebar3 tar)
```

The smallest proper fix is therefore a locked dependency update, not a source
workaround, module exclusion, or test change.
