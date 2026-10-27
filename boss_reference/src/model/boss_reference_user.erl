-module(boss_reference_user,
        [Id,
         Username::string(),
         DisplayName::string(),
         Email::string(),
         Role::string(),
         Active::boolean(),
         PasswordHash::binary()]).
-compile(tuple_calls).

-compile(export_all).

-has({assigned_issues, many,
      [{module, boss_reference_issue}, {foreign_key, assignee_id},
       {order_by, created_at}, {descending, true}]}).

validation_tests() ->
    [{fun() -> Username =/= undefined andalso Username =/= [] end,
      "Username is required"},
     {fun() -> length(Username) =< 40 end, "Username is too long"},
     {fun() -> DisplayName =/= undefined andalso DisplayName =/= [] end,
      "Display name is required"},
     {fun() -> Email =/= undefined andalso Email =/= [] end,
      "Email is required"},
     {fun() -> lists:member(Role, ["owner", "member"]) end,
      "Role must be owner or member"},
     {fun() -> PasswordHash =/= undefined andalso PasswordHash =/= <<>> end,
      "Password hash is required"}].

validation_tests(on_create) ->
    validation_tests() ++
        [{fun unique_username/0, "Username must be unique"},
         {fun unique_email/0, "Email must be unique"}];
validation_tests(on_update) ->
    validation_tests() ++
        [{fun unique_username/0, "Username must be unique"},
         {fun unique_email/0, "Email must be unique"}].

unique_username() ->
    unique_attribute(username, Username).

unique_email() ->
    unique_attribute(email, Email).

unique_attribute(Attribute, Value) ->
    Matches = boss_db:find(boss_reference_user,
                           [{Attribute, 'equals', Value}]),
    lists:all(fun(User) -> User:id() =:= Id end, Matches).
