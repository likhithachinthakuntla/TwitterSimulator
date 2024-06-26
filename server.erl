-module(server).
-import(maps, []).
-export[start/0].

start() ->
    io:fwrite("\n\nTwitter Engine (Clone) \n\n"),
    %Table = ets:new(t, [ordered_set]),
    Table = ets:new(messages, [ordered_set, named_table, public]),
    Client_Socket_Mapping = ets:new(clients, [ordered_set, named_table, public]),
    {ok, ListenSocket} = gen_tcp:listen(1204, [binary, {keepalive, true}, {reuseaddr, true}, {active, false}]),
    await_connections(ListenSocket, Table, Client_Socket_Mapping).

await_connections(Listen, Table, Client_Socket_Mapping) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    ok = gen_tcp:send(Socket, "YIP"),
    spawn(fun() -> await_connections(Listen, Table, Client_Socket_Mapping) end),
    %conn_loop(Socket).
    do_recv(Socket, Table, [], Client_Socket_Mapping).

do_recv(Socket, Table, Bs, Client_Socket_Mapping) ->
    io:fwrite("Do Receive\n\n"),
    case gen_tcp:recv(Socket, 0) of
        {ok, Data1} ->
            
            Data = re:split(Data1, ","),
            Type = binary_to_list(lists:nth(1, Data)),

            io:format("\n\nDATA: ~p\n\n ", [Data]),
            io:format("\n\nTYPE: ~p\n\n ", [Type]),

            if 
                Type == "register" ->
                    UserName = binary_to_list(lists:nth(2, Data)),
                    PID = binary_to_list(lists:nth(3, Data)),
                    io:format("\nPID:~p\n", [PID]),
                    io:format("\nSocket:~p\n", [Socket]),
                    io:format("Type: ~p\n", [Type]),
                    io:format("\n~p wants to register an account\n", [UserName]),
                    
                    Output = ets:lookup(Table, UserName),
                    io:format("Output: ~p\n", [Output]),
                    if
                        Output == [] ->

                            ets:insert(Table, {UserName, [{"followers", []}, {"tweets", []}]}),      
                            ets:insert(Client_Socket_Mapping, {UserName, Socket}),                
                            Temp_List = ets:lookup(Table, UserName),
                            io:format("~p", [lists:nth(1, Temp_List)]),

                          
                            ok = gen_tcp:send(Socket, "User registered"), % RESPOND BACK - YES/NO
                            io:fwrite("Key not found in database\n");
                        true ->
                            ok = gen_tcp:send(Socket, "Username not available! Please provide a new username"),
                            io:fwrite("Duplicate key!\n")
                    end,
                    do_recv(Socket, Table, [UserName], Client_Socket_Mapping);

                Type == "tweet" ->
                    UserName = binary_to_list(lists:nth(2, Data)),
                    Tweet = binary_to_list(lists:nth(3, Data)),
                    io:format("\n ~p sent the following tweet: ~p", [UserName, Tweet]),
                    
                    % {ok, Val} = maps:find(UserName, Map),
                    Val = ets:lookup(Table, UserName),
                    io:format("Output: ~p\n", [Val]),
                    Val3 = lists:nth(1, Val),
                    Val2 = element(2, Val3),
                    Val1 = maps:from_list(Val2),
                    {ok, CurrentFollowers} = maps:find("followers",Val1),                         
                    {ok, CurrentTweets} = maps:find("tweets",Val1),

                    NewTweets = CurrentTweets ++ [Tweet],
                    io:format("~p~n",[NewTweets]),
                    
                    ets:insert(Table, {UserName, [{"followers", CurrentFollowers}, {"tweets", NewTweets}]}),

                    Output_After_Tweet = ets:lookup(Table, UserName),
                    io:format("\nOutput after tweeting: ~p\n", [Output_After_Tweet]),
                  
                    sendMessage(Socket, Client_Socket_Mapping, Tweet, CurrentFollowers, UserName),
                    ok = gen_tcp:send(Socket, "Server processed tweet\n"),
                    do_recv(Socket, Table, [UserName], Client_Socket_Mapping);

                Type == "retweet" ->
                    Person_UserName = binary_to_list(lists:nth(2, Data)),
                    UserName = binary_to_list(lists:nth(3, Data)),
                    Sub_User = string:strip(Person_UserName, right, $\n),
                    io:format("User to retweet from: ~p\n", [Sub_User]),
                    Tweet = binary_to_list(lists:nth(4, Data)),
                    Out = ets:lookup(Table, Sub_User),
                    if
                        Out == [] ->
                            io:fwrite("User not found!\n");
                        true ->
                            % Current User
                            Out1 = ets:lookup(Table, UserName),
                            Val3 = lists:nth(1, Out1),
                            Val2 = element(2, Val3),
                            Val1 = maps:from_list(Val2),
                            % User we are retweeting from
                            Val_3 = lists:nth(1, Out),
                            Val_2 = element(2, Val_3),
                            Val_1 = maps:from_list(Val_2),
                            % current user
                            {ok, CurrentFollowers} = maps:find("followers",Val1),
                            % user we are retweeting from
                            {ok, CurrentTweets} = maps:find("tweets",Val_1),
                            io:format("Tweet to be re-posted: ~p\n", [Tweet]),
                            CheckTweet = lists:member(Tweet, CurrentTweets),
                            if
                                CheckTweet == true ->
                                    NewTweet = string:concat(string:concat(string:concat("re:",Sub_User),"->"),Tweet),
                                    sendMessage(Socket, Client_Socket_Mapping, NewTweet, CurrentFollowers, UserName);
                                true ->
                                    io:fwrite("Tweet not found!\n")
                            end     
                    end,
                    io:format("\n ~p wants to retweet something\n", [UserName]),
                    ok = gen_tcp:send(Socket, "Server processed retweet\n"),
                    do_recv(Socket, Table, [UserName], Client_Socket_Mapping);

                Type == "subscribe" ->
                    UserName = binary_to_list(lists:nth(2, Data)),
                    SubscribedUserName = binary_to_list(lists:nth(3, Data)),
                    Sub_User = string:strip(SubscribedUserName, right, $\n),
                    Output1 = ets:lookup(Table, Sub_User),
                    if
                        Output1 == [] ->
                            io:fwrite("The username entered not found! Please try again. \n");
                        true ->

                            Val = ets:lookup(Table, Sub_User),
                            Val3 = lists:nth(1, Val),
                            Val2 = element(2, Val3),

                            Val1 = maps:from_list(Val2),                            
                            {ok, CurrentFollowers} = maps:find("followers",Val1),
                            {ok, CurrentTweets} = maps:find("tweets",Val1),

                            NewFollowers = CurrentFollowers ++ [UserName],
                            io:format("~p~n",[NewFollowers]),
                        
                            ets:insert(Table, {Sub_User, [{"followers", NewFollowers}, {"tweets", CurrentTweets}]}),

                            Output2 = ets:lookup(Table, Sub_User),
                            io:format("\nOutput after subscribing: ~p\n", [Output2]),

                            ok = gen_tcp:send(Socket, "Subscribed!"),

                            do_recv(Socket, Table, [UserName], Client_Socket_Mapping)
                    end,
                    io:format("\n ~p wants to subscribe to ~p\n", [UserName, Sub_User]),
                    
                    ok = gen_tcp:send(Socket, "Server processed subscription. Subscribed!"),
                    do_recv(Socket, Table, [UserName], Client_Socket_Mapping);

                Type == "query" ->
                    Option = binary_to_list(lists:nth(3, Data)),
                    UserName = binary_to_list(lists:nth(2, Data)),
                    io:format("Query: The current username is -> ~p\n", [UserName]),
                    if
                        Option == "1" ->
                            io:fwrite("My mentions!\n"),
                            MyUserName = binary_to_list(lists:nth(4, Data)),
                            Sub_UserName = ets:first(Table),
                            Sub_User = string:strip(Sub_UserName, right, $\n),
                            io:format("Sub_UserName: ~p\n", [Sub_User]),
                            Tweets = searchAllTweets("@", Table, Sub_User, MyUserName , []),
                            ok = gen_tcp:send(Socket, Tweets);
                        Option == "2" ->
                            io:fwrite("Hashtag Search\n"),
                            Hashtag = binary_to_list(lists:nth(4, Data)),
                            Sub_UserName = ets:first(Table),
                            Sub_User = string:strip(Sub_UserName, right, $\n),
                            io:format("Sub_UserName: ~p\n", [Sub_User]),
                            Tweets = searchAllTweets("#", Table, Sub_User, Hashtag , []),
                            ok = gen_tcp:send(Socket, Tweets);
                        true ->
                            io:fwrite("Subscribed User Search\n"),
                            Sub_UserName = binary_to_list(lists:nth(4, Data)),
                            Sub_User = string:strip(Sub_UserName, right, $\n),
                            io:format("Sub_UserName: ~p\n", [Sub_User]),
                            Tweets = searchUserTweets(Table, Sub_User),
                            ok = gen_tcp:send(Socket, Tweets)
                    end,
                    io:format("\n ~p wants to query", [UserName]),
                    do_recv(Socket, Table, [UserName], Client_Socket_Mapping);
                true ->
                    io:fwrite("\n Anything else!")
            end;

        {error, closed} ->
            {ok, list_to_binary(Bs)};
        {error, Reason} ->
            io:fwrite("error"),
            io:fwrite(Reason)
    end.

searchUserTweets(Table, UserName) ->
    Val = ets:lookup(Table, UserName),
    Length = length(Val),
    if
        Length == 0 ->
            io:fwrite("User Not found\n"),
            [];
        true ->
            Val3 = lists:nth(1, Val),
            Val2 = element(2, Val3),
            Val1 = maps:from_list(Val2),                            
            {ok, CurrentTweets} = maps:find("tweets",Val1),
            CurrentTweets
    end.

searchAllTweets(Symbol, Table, Key, Word, Found) ->
    Search = string:concat(Symbol, Word),
    io:format("Word to be searched: ~p~n", [Search]),
    if
        Key == '$end_of_table' ->
            io:fwrite("Found tweets: ~p~n", [Found]),
            Found;
        true ->
            io:fwrite("Current Row key: ~p~n", [Key]),
            Val = ets:lookup(Table, Key),
            Val3 = lists:nth(1, Val),
            Val2 = element(2, Val3),
            Val1 = maps:from_list(Val2),                              
            {ok, CurrentTweets} = maps:find("tweets",Val1),
            io:fwrite("CurrentTweets: ~p~n", [CurrentTweets]),
            FilteredTweets = [S || S <- CurrentTweets, string:str(S, Search) > 0],
            io:fwrite("FilteredTweets: ~p~n", [FilteredTweets]),
            Found1 = Found ++ FilteredTweets,
            CurrentRow_Key = ets:next(Table, Key),
            searchAllTweets(Symbol, Table, CurrentRow_Key, Word, Found1)
    end.


% searchWholeTable(Table, Key, UserName) ->
%     Val = ets:lookup(Table, Key),
%     if
%         Key == UserName ->
%             Val3 = lists:nth(1, Val),
%             Val2 = element(2, Val3),
%             Val1 = maps:from_list(Val2),                            
%             {ok, CurrentTweets} = maps:find("tweets",Val1),
%             CurrentTweets;
%         true ->
%             CurrentRow_Key = ets:next(Table, Key),
%             searchWholeTable(Table, CurrentRow_Key, UserName)
%     end.

sendMessage(Socket, Client_Socket_Mapping, Tweet, Subscribers, UserName) ->
    if
        Subscribers == [] ->
            io:fwrite("\nNo followers!\n");
        true ->
            [Client_To_Send | Remaining_List ] = Subscribers,
            io:format("Client to send: ~p\n", [Client_To_Send]),
            io:format("\nRemaining List: ~p~n",[Remaining_List]),
            Client_Socket_Row = ets:lookup(Client_Socket_Mapping,Client_To_Send),
            Val3 = lists:nth(1, Client_Socket_Row),
            Client_Socket = element(2, Val3),
            io:format("\nClient Socket: ~p~n",[Client_Socket]),
            
            ok = gen_tcp:send(Client_Socket, ["New tweet received\n",UserName,":",Tweet]),
            ok = gen_tcp:send(Socket, "Your tweet has been sent\n"),
            
            sendMessage(Socket, Client_Socket_Mapping, Tweet, Remaining_List, UserName)
    end,
    io:fwrite("Send message\n").

% Implement a twitter-like engine with following functionality:
% 1. Register Account
% 2. Send Tweet
%      - tweets can have hashtags (e.g., #COP5615isgreat) and mentions (@bestuser)
% 3. Subscribe to user's tweet
% 4. Re-tweets
% 5. Allow querying tweets subscribed to, tweets with specific hashtags, 
%    tweets in which the user is mentioned (my mentions)
% 
% 6. If the user is connected, deliver the above types of tweets live (without querying)
% 7. Simulate as many users as you can
% 8. Simulate periods of live connection and disconnection for users
% 
% 9. Simulate a Zipf distribution on the number of subscribers. For accounts with a lot of subscribers
%    increase the number of tweets -- make some of these messages re-tweets.
%     
% 10. Other Considerations:
%     1. The client part (send/receive tweets) and the engine (distribute tweets)
%        have to be in seperate processes.
%         
%     2. Preferably, you use multiple independent client processes that simulate
%        thousands of clients and a single-engine process
%        
%     3. You need to measure various aspects of your simulator and report performance 
%     
%     4. Submit your code and a report with performance numbers with instructions on how to run it.