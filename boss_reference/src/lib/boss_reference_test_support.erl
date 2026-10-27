-module(boss_reference_test_support).

-export([csrf_token/1,
         cookie_header/1,
         cookie_value/2,
         form_headers/2,
         urlencode_form/1,
         csrf_form/2,
         csrf_form_without_token/1,
         csrf_form_with_wrong_token/1,
         clear_session/1]).

csrf_token(Body) when is_binary(Body) ->
    csrf_token(binary_to_list(Body));
csrf_token(Body) when is_list(Body) ->
    Patterns = [
        "name=[\\\"']csrfmiddlewaretoken[\\\"'][^>]*value=[\\\"']([^\\\"']+)",
        "value=[\\\"']([^\\\"']+)[\\\"'][^>]*name=[\\\"']csrfmiddlewaretoken"
    ],
    first_capture(Patterns, Body).

cookie_header(Headers) ->
    Pairs = [cookie_pair(Value) || {Name, Value} <- Headers,
                                    is_set_cookie(Name)],
    string:join([Pair || Pair <- Pairs, Pair =/= undefined], "; ").

cookie_value(Name, Headers) ->
    case lists:dropwhile(fun({HeaderName, _}) ->
                                 not is_set_cookie(HeaderName)
                         end, Headers) of
        [] -> undefined;
        SetCookies -> cookie_value_from_headers(Name, SetCookies)
    end.

form_headers(Body, Headers) ->
    [{"Content-Type", "application/x-www-form-urlencoded"},
     {"Cookie", cookie_header(Headers)} |
     case csrf_token(Body) of
         undefined -> [];
         Token -> [{"X-CSRFToken", Token}]
     end].

urlencode_form(Fields) ->
    mochiweb_util:urlencode(Fields).

csrf_form(Fields, Token) ->
    urlencode_form([{"csrfmiddlewaretoken", Token}|Fields]).

csrf_form_without_token(Fields) ->
    urlencode_form(Fields).

csrf_form_with_wrong_token(Fields) ->
    csrf_form(Fields, "deliberately-wrong-token").

clear_session(SessionID) ->
    boss_session:delete_session(SessionID).

first_capture([], _Body) ->
    undefined;
first_capture([Pattern|Rest], Body) ->
    case re:run(Body, Pattern, [{capture, [1], list}]) of
        {match, [Token]} -> Token;
        nomatch -> first_capture(Rest, Body)
    end.

cookie_pair(Value) when is_binary(Value) ->
    cookie_pair(binary_to_list(Value));
cookie_pair(Value) when is_list(Value) ->
    case string:tokens(Value, ";") of
        [Pair|_] -> Pair;
        [] -> undefined
    end.

cookie_value_from_headers(_Name, []) ->
    undefined;
cookie_value_from_headers(Name, [{HeaderName, Value}|Rest]) ->
    case is_set_cookie(HeaderName) of
        false -> cookie_value_from_headers(Name, Rest);
        true ->
            Pair = cookie_pair(Value),
            case string:tokens(Pair, "=") of
                [Name, CookieValue|_] -> CookieValue;
                _ -> cookie_value_from_headers(Name, Rest)
            end
    end.

is_set_cookie(Name) when is_binary(Name) ->
    is_set_cookie(binary_to_list(Name));
is_set_cookie("Set-Cookie") -> true;
is_set_cookie("set-cookie") -> true;
is_set_cookie(_) -> false.
