-module(boss_reference_http_test).

-export([start/0]).

start() ->
    {atomic, _} = boss_reference_fixtures:seed(),
    boss_web_test:get_request(
      "/", [],
      [fun boss_assert:http_ok/1,
       fun(Response) -> boss_assert:tag_with_text("h1", "Chicago Boss reference application", Response) end,
       fun(Response) -> boss_assert:tag_with_text("dd", "1", Response) end],
      ["Check seeded public dashboard",
       fun(_Response) ->
           boss_web_test:get_request(
             "/projects/legacy-baseline", [],
             [fun boss_assert:http_ok/1,
              fun(Response) -> boss_assert:tag_with_text("h1", "Legacy Baseline", Response) end],
             [])
       end,
       "Check custom project route",
       fun(_Response) ->
           boss_web_test:get_request(
             "/issues/boss_reference_issue-4", [],
             [fun boss_assert:http_ok/1,
              fun(Response) -> boss_assert:tag_with_text("h1", "Broken link on dashboard", Response) end],
             [])
       end]).
