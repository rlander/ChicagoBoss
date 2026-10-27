-module(boss_reference_fixtures).
-compile(tuple_calls).

-export([seed/0, seed_minimal/0]).

seed() ->
    boss_db:transaction(fun seed_inner/0).

seed_minimal() ->
    boss_db:transaction(fun() ->
        {ok, Owner} = ensure_user("owner", "Reference Owner",
                                  "owner@example.test", "owner", "owner"),
        {ok, Project} = ensure_project("legacy-baseline", "Legacy Baseline",
                                       Owner:id()),
        {ok, Owner, Project}
    end).

seed_inner() ->
    {ok, Owner} = ensure_user("owner", "Reference Owner",
                              "owner@example.test", "owner", "owner"),
    {ok, Member} = ensure_user("member", "Reference Member",
                               "member@example.test", "member", "member"),
    {ok, Project} = ensure_project("legacy-baseline", "Legacy Baseline",
                                   Owner:id()),
    {ok, OpenIssue} = ensure_issue(Project:id(), "Broken link on dashboard",
                                   "The dashboard link is incorrect.", "open",
                                   Member:id()),
    {ok, ClosedIssue} = ensure_issue(Project:id(), "Document old route",
                                     "Document the conventional route.", "closed",
                                     Owner:id()),
    {ok, _Comment} = ensure_comment(OpenIssue:id(), Member:id(),
                                    "I can reproduce this from the fixture."),
    {ok, Regression} = ensure_label("regression"),
    {ok, _Live} = ensure_label("live-update"),
    {ok, _} = boss_reference_domain:add_label(OpenIssue, Regression),
    {ok, Owner, Member, Project, OpenIssue, ClosedIssue}.

ensure_user(Username, DisplayName, Email, Role, Password) ->
    case boss_db:find(boss_reference_user,
                      [{username, 'equals', Username}], [{limit, 1}]) of
        [User|_] -> {ok, User};
        [] ->
            User0 = boss_reference_user:new(
                      id, Username, DisplayName, Email, Role, true,
                      boss_reference_auth:password_hash(Password)),
            User0:save()
    end.

ensure_project(Slug, Name, OwnerID) ->
    case boss_db:find(boss_reference_project,
                      [{slug, 'equals', Slug}], [{limit, 1}]) of
        [Project|_] -> {ok, Project};
        [] ->
            Project0 = boss_reference_project:new(
                         id, Slug, Name, OwnerID, calendar:universal_time()),
            Project0:save()
    end.

ensure_issue(ProjectID, Title, Body, Status, AssigneeID) ->
    case boss_db:find(boss_reference_issue,
                      [{project_id, 'equals', ProjectID},
                       {title, 'equals', Title}], [{limit, 1}]) of
        [Issue|_] -> {ok, Issue};
        [] ->
            Issue0 = boss_reference_issue:new(
                       id, Title, Body, Status, ProjectID, AssigneeID,
                       calendar:universal_time()),
            Issue0:save()
    end.

ensure_comment(IssueID, AuthorID, Body) ->
    case boss_db:find(boss_reference_comment,
                      [{issue_id, 'equals', IssueID},
                       {body, 'equals', Body}], [{limit, 1}]) of
        [Comment|_] -> {ok, Comment};
        [] ->
            Comment0 = boss_reference_comment:new(
                          id, Body, IssueID, AuthorID, calendar:universal_time()),
            Comment0:save()
    end.

ensure_label(Name) ->
    Slug = boss_reference_domain:normalize_label(Name),
    case boss_db:find(boss_reference_label,
                      [{slug, 'equals', Slug}], [{limit, 1}]) of
        [Label|_] -> {ok, Label};
        [] ->
            Label0 = boss_reference_label:new(id, Name, Slug),
            Label0:save()
    end.
