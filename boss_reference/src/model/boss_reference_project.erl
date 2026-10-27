-module(boss_reference_project,
        [Id,
         Slug::string(),
         Name::string(),
         OwnerId,
         CreatedAt::datetime()]).
-compile(tuple_calls).

-compile(export_all).

-belongs_to_user(owner).
-has({issues, many,
      [{module, boss_reference_issue},
       {foreign_key, project_id},
       {order_by, created_at}, {descending, true}]}).

validation_tests() ->
    [{fun() -> Slug =/= undefined andalso Slug =/= [] end,
      "Slug is required"},
     {fun() -> length(Slug) =< 80 end, "Slug is too long"},
     {fun() -> re:run(Slug, "^[a-z0-9][a-z0-9-]*$", [{capture, none}]) =:= match end,
      "Slug contains invalid characters"},
     {fun() -> Name =/= undefined andalso Name =/= [] end,
      "Name is required"},
     {fun() -> length(Name) =< 120 end, "Name is too long"},
     {fun valid_owner/0, "Owner must exist"}].

validation_tests(on_create) ->
    validation_tests() ++ [{fun unique_slug/0, "Slug must be unique"}];
validation_tests(on_update) ->
    validation_tests() ++ [{fun unique_slug/0, "Slug must be unique"}].

valid_owner() ->
    OwnerId =/= undefined andalso boss_db:find(OwnerId) =/= undefined.

unique_slug() ->
    Matches = boss_db:find(boss_reference_project,
                           [{slug, 'equals', Slug}]),
    lists:all(fun(Project) -> Project:id() =:= Id end, Matches).
