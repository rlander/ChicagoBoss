-module(boss_reference_comment,
        [Id,
         Body::string(),
         IssueId,
         AuthorId,
         CreatedAt::datetime()]).
-compile(tuple_calls).

-compile(export_all).

-belongs_to(issue).
-belongs_to_user(author).

validation_tests() ->
    [{fun() -> Body =/= undefined andalso Body =/= [] end,
      "Comment is required"},
     {fun() -> length(Body) =< 1000 end, "Comment is too long"},
     {fun() -> IssueId =/= undefined andalso boss_db:find(IssueId) =/= undefined end,
      "Issue must exist"},
     {fun() -> AuthorId =/= undefined andalso boss_db:find(AuthorId) =/= undefined end,
      "Author must exist"}].

validation_tests(on_create) -> validation_tests();
validation_tests(on_update) -> validation_tests().
