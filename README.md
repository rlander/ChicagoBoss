Chicago Boss: Start small, dream big
====================================
[![Build Status](https://travis-ci.org/ChicagoBoss/ChicagoBoss.svg?branch=master)](https://travis-ci.org/ChicagoBoss/ChicagoBoss)

This branch is maintained and validated with Erlang/OTP 21.3.8.24 and Rebar3
3.15.2. The immutable dependency resolution is recorded in `rebar.lock`.

Chicago Boss is a server framework inspired by Rails and written in Erlang. It
offers all the conveniences of modern web development, including Comet. What sets
Chicago Boss apart from other non-Erlang frameworks is that it can handle large
amounts of traffic without any drop in performance. What sets Chicago Boss apart
from other Erlang frameworks is that it is easy to set up and use.

WARNING: Chicago Boss does not work with Erlang R16B03 due to an error in erl_syntax

60-second Quickstart
--------------------

After downloading and extracting, install the supplied Rebar3 template once
and use Rebar3 for every build, test, release, and generated application. The
root project can be checked first with:

```console
rebar3 compile
rebar3 eunit
rebar3 ct
```

The current Common Test suite is intentionally unchanged and currently fails
because it expects `boss_mq` to be started by the test setup and still expects
the historical `poll/2` result shape. EUnit is the passing unit-test command;
Common Test remains a separate, documented test maintenance task.

Install the template and create an application with:

```console
mkdir -p ~/.config/rebar3/templates
cp -R skel/. ~/.config/rebar3/templates/
rebar3 new chicagoboss mynewproject
cd mynewproject
rebar3 compile
rebar3 eunit
rebar3 ct
```

The generated project contains its own exact Boss Git dependency and uses
`config/sys.config` and `config/vm.args` for releases; its development shell
uses `config/sys.dev.config` and does not copy this checkout or a
prebuilt dependency directory. The `boss_url` and `boss_ref` template
variables can be overridden for an isolated local-mirror validation run.

The historical Makefile, bundled Rebar 2 executable, `rebar.config.script`,
`boss.config`, `init.sh`, `init-dev.sh`, Windows batch wrappers, and Boss Rebar
2 plugin are not part of the active build workflow.


Development Server
------------------

Start a generated application in the foreground with the Rebar3 shell:

```console
rebar3 shell
```

The shell uses `config/sys.dev.config`, and the default generated HTTP port is
`18001`. Visit `http://127.0.0.1:18001/health` after the application starts.
The development config sets `boss.developing_app`; `boss_app` starts the
historical MochiWeb `reloader` before the framework initializes. Controller,
view, library, and model changes are then compiled/loaded through the legacy
development loader without restarting the VM.

Rebar3 3.15.2 loads the shell sys config but does not apply a `vm_args` entry
from `rebar.config`. `config/vm.dev.args` is retained for alternate launchers;
the canonical `rebar3 shell` path starts the reloader from `boss_app` instead.
Production releases continue to use `config/sys.config` and `config/vm.args`
and do not enable development reload.


Releases
--------

`rebar3 release` assembles an unpacked OTP release under
`_build/default/rel/<application>`. It does not create a distributable archive
by itself:

```console
rebar3 release
_build/default/rel/mynewproject/bin/mynewproject foreground
```

The generated release script also supports the usual lifecycle commands:

```console
_build/default/rel/mynewproject/bin/mynewproject start
_build/default/rel/mynewproject/bin/mynewproject stop
_build/default/rel/mynewproject/bin/mynewproject restart
_build/default/rel/mynewproject/bin/mynewproject remote_console
```

`rebar3 tar` first assembles the release when necessary and creates a tarball
for distribution. Use `rebar3 release` when you want a runnable directory and
`rebar3 tar` when you want to transport or publish the packaged release.

For Windows, Rebar3 itself is usable when Erlang and `rebar3` are on `PATH`,
but the old `.bat` wrappers are gone. The current build also uses a POSIX
`sh -c` post-compile hook for the historical `mimetypes` dependency, so native
CMD/PowerShell execution has not been validated. Use a POSIX-compatible shell
such as Git Bash/MSYS/WSL, or replace that hook before claiming native Windows
support.

The historical `mimetypes` application generates dispatch modules when it
starts. Rebar3 compilation runs a post-compile hook to materialize those
modules, and the release configuration copies them into the packaged release.
This preserves the historical dependency behavior but is a known portability
boundary. The default Cowboy dispatcher also uses Cowboy's `cow_mimetypes`
mapping; removing the legacy dependency completely requires a separate source
and backend-support change.

The project name should be a legal Erlang atom, i.e. start with a lowercase
letter and contain only letters, digits, and underscores (for easy compatibility is recommended name the project dir and app name the same).


Dependencies
------------

* Erlang/OTP 21.3.8.24 -

    <http://www.erlang.org/download.html>

  * Check with `erlang:system_info(otp_release)`.

* Rebar3 3.15.2 -

  * Check with `rebar3 --version`.
  * Do not use the newest Rebar3 release for this historical baseline without
    first validating it against OTP 21.3.8.24.

The exact dependency revisions are recorded in `rebar.lock` and the human
readable manifest at `config/dependency-lock.tsv`.

`erlmc` remains in the locked transitive dependency graph because it is part of
the historical `boss_db` closure. It is excluded from the default release
startup closure because its application metadata declares an `erlmc:start/2`
callback that the checkout does not provide. It can be repaired separately if
Memcached support is required.

`medici` is also retained as a locked historical dependency but is not started
by the default release because it connects to an external Tokyo Tyrant service
during application startup. Applications using that backend must configure and
start it explicitly.

The complete migration boundary, including options that were not carried over
from the historical `boss.config`, is documented in
[`docs/rebar3-compatibility-gaps.md`](docs/rebar3-compatibility-gaps.md).


Admin Interface
---------------

You probably want to install the CB admin interface. Download it from

    <https://github.com/ChicagoBoss/cb_admin>


Upgrades
--------

Uprading used to be a pain but now it is easy. See README_UPGRADE


Database Setup
--------------

By default CB uses an in-memory database that needs no configuration. To start
working with an actual database, See README_DATABASE


Philosophy and Features
-----------------------

Why another web framework? Because Rails apps are slow and Node apps are messy.
Chicago Boss takes advantage of functional programming and under-the-hood
compiler magic to provide clean, understandable controller logic, Django-style
templates, and an ORM based on Erlang's parameterized modules. The best part is
that the network I/O is 100% asynchronous so you can seamlessly integrate Comet
endpoints into your app, and you never have to worry about a slow database
query dragging down unrelated requests.

CB ships with all the tools you need to build a feature-ful website, including
sessions, URL routing, filtering requests and post-processing responses,
frameworks for sending and receiving email, JSON generation, Comet via
long-poll and message queues, and internationalization (i18n). Read on for
details.

*Databases*. Chicago Boss currently supports MySQL, PostgreSQL, Tokyo Tyrant,
Mnesia, MongoDB, and Riak. In CB 0.5.4 and later, you can mix and match
databases by configuring Boss to use vertical shards. For SQL databases, the
conventions are similar to Rails (plural nouns for the table names, object_id
for foreign keys, etc.).

*BossRecords*. Boss's take on ActiveRecord is called a BossRecord, which is
an Erlang parameterized module on steroids. You instantiate a BossRecord like
a regular parameterized module:

```erlang
Article = article:new('id', "This is a title", "This is a body")
```

But then CB generates functions and attaches them to BossRecords, so you can
write code like

```erlang
{ok, SavedArticle} = Article:save()
```

Before saving to the database, the save() function will call a function called
validation_tests(), where you can perform custom validation logic.

CB also generates getter functions which can be invoked directly in templates,
so in your template you can write things like

```erlang
{{ article.title }}
```

Speaking of which...

*Templates*. Chicago Boss uses ErlyDTL, an Erlang implentation of Django template
language. In fact, Chicago Boss originated with a rewrite of ErlyDTL, and the same
person maintains both projects so you always get the latest ErlyDTL features. Templates
can access and loop over values stored in proplists, dictionaries, and BossRecords,
so you can move data from the database to your templates with a minimum of massaging.

In addition, templates are tightly integrated with Boss's i18n machinery. The admin
interface automatically parses templates for translatable strings, and Boss can
choose which language to serve based on the request's Accept-Languages header and
the calculated translation coverage for a particular page. Multi-language websites
are easy to develop with Chicago Boss.

*Controllers*. Erlang's pattern-matching is a perfect fit for writing
controller logic. Your controllers are passed the URL method (GET, POST) and a list
of URL tokens, and just need to return a tuple telling Boss what to do, for example:

* `{ok, Variables}` - render the default template with Variables
* `{render_other, Variables}` - render another template
* `{redirect, URL}` - redirect the request
* `{json, Proplist}` - encode the Proplist as JSON and send to the client
* `{output, Data}` - send Data to the client

If you come from Rails, you'll instantly notice the benefit of Erlang's
language design: you don't need an ugly `case request.method` statement inside
every action, you never have atrocities like `render and return`, and you can
always see every variable that is in scope. In CB apps, controller logic is
always concise and usually a pleasure to read.

*Sessions*. You can configure sessions to be stored in memory (ETS) or in an
Mnesia database.  The `boss_session` and `boss_flash` modules provide functions
for storing and retrieving session information.

*Routes*. By default, Chicago Boss uses the same routing conventions as Ruby on
Rails (`/controller/action/id`). You can customize the routes and provide
a base URL in the priv/application.routes file. Of course, most routing occurs
with the pattern-matching controller logic, e.g.
```erlang
posts('GET', ["category", Category]) ->
```

You can then generate URLs to match controller patterns in your templates like
so:

    {% url action="posts" category="some category" %}

*Email*. Chicago Boss ships with a miniature MVC for sending multipart emails.
Emails can be templated with ErlyDTL, and it is easy to provide plain-text and
HTML versions of the same email. In testing environments, email can be sent
directly to the recipient, or in production can be relayed to an SMTP server.

A Chicago Boss server can also receive email over SMTP. Each email address maps
to a function in your incoming mail controller, so it is easy to write
well-organized email applications. Your email controller has access to the
exact same resources as your web controllers, including database requests,
BossRecord instantiation, and the message queue; web and email are fully
integrated.

*Comet*. It's simple to write a Comet endpoint in Chicago Boss. Unlike any
other language, Erlang gives you the benefits of asynchronous network
communcation without using callbacks. Here is a trivial example of a long-poll
controller:

```erlang
longpoll('GET', [Channel]) ->
    {ok, Timestamp, Messages} = boss_mq:pull(Channel, last),
    {json, [{timestamp, Timestamp}, {messages, Messages}]}.
```

The call to `pull` blocks until a message is received. Because processes are
cheap in Erlang, the overhead of keeping alive a blocking request is very small
(just a few kilobytes of memory, compared to megabytes in Rails). You can
thus keep alive thousands of Comet request with just a few megabytes of memory.
Also notice that the controller logic remains nice and clean (no callbacks). We
can perform an arbitrary sequence of asynchronous network requests without
increasing the scope level.

*Events*. An interesting feature of Chicago Boss is the events API called
BossNews. With it, you can watch a record or a set of records for changes,
then execute a callback when a change is witnessed. Combined with long-polling,
you can provide a real-time view of your database on your website. Events can
also be used to provide a clean separation of business logic and notification
logic.

*Tests*. Chicago Boss has a kick-ass testing framework. Once you try it you
won't go back. That's all I'll say for now.


Future Work
-----------

Most of Chicago Boss's planned features have been implemented at this point. It
hasn't really been tested in a distributed environment, but it's already
running on a few public-facing websites, and many more internal websites (or so
I am told). It would be nice to add more databases (such as CouchDB and Oracle)
and support horizontal sharding. The last main feature before 1.0 will be
the ability to distribute apps written in Chicago Boss as standalone OTP
applications.


Further Reading
---------------

See the FAQ and API files located at

<http://www.chicagoboss.org/>

If you need help getting started, check the new pdf tutorial:

<http://www.chicagoboss.org/tutorial.pdf>

Be sure to also check the wiki

<https://github.com/ChicagoBoss/ChicagoBoss/wiki>

There's also the mailing list:

<http://groups.google.com/group/chicagoboss>

If you want to contribute to CB

[CODING_STANDARDS.md](https://github.com/ChicagoBoss/ChicagoBoss/blob/master/CODING_STANDARDS.md)

View the CHANGELOG.md

[CHANGELOG.md](https://github.com/ChicagoBoss/ChicagoBoss/blob/master/CHANGELOG.md)
