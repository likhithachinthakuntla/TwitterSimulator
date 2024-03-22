-module(client).
-export[start/0, get_and_parse_user_input/2, loop/1].

start() ->
    io:fwrite("\n\n Started a new client\n\n"),
    PortNumber = 1204,
    IPAddress = "localhost",
    {ok, Sock} = gen_tcp:connect(IPAddress, PortNumber, [binary, {packet, 0}]),
    io:fwrite("\n\n Just sent my request to the server\n\n"),
    spawn(client, get_and_parse_user_input, [Sock, "_"]),
    loop(Sock).

loop(Sock) ->
    receive
        {tcp, Sock, Data} ->
            io:fwrite("Message received from Server\n"),
            io:fwrite(Data),
            loop(Sock);
        {tcp, closed, Sock} ->  
            io:fwrite("Connection with client can't be made - TCP closed")
        end.

get_and_parse_user_input(Sock, UserName) ->
    {ok, [CommandType]} = io:fread("\nPlease enter the command: ", "~s\n"),
    io:fwrite(CommandType),
    if 
        CommandType == "register" ->
            UserName1 = register_account(Sock);
        CommandType == "tweet" ->
            if
                UserName == "_" ->
                    io:fwrite("Registration required!\n"),
                    UserName1 = get_and_parse_user_input(Sock, UserName);
                true ->
                    send_tweet(Sock,UserName),
                    UserName1 = UserName
            end;
        CommandType == "retweet" ->
            if
                UserName == "_" ->
                    io:fwrite("Registration required!\n"),
                    UserName1 = get_and_parse_user_input(Sock, UserName);
                true ->
                    re_tweet(Sock, UserName),
                    UserName1 = UserName
            end;
        CommandType == "subscribe" ->
            if
                UserName == "_" ->
                    io:fwrite("Registration required!\n"),
                    UserName1 = get_and_parse_user_input(Sock, UserName);
                true ->
                    subscribe_to_user(Sock, UserName),
                    UserName1 = UserName
            end;
        CommandType == "query" ->
            if
                UserName == "_" ->
                    io:fwrite("Registration required!\n"),
                    UserName1 = get_and_parse_user_input(Sock, UserName);
                true ->
                    query_tweet(Sock, UserName),
                    UserName1 = UserName
            end;
        CommandType == "logout" ->
            if
                UserName == "_" ->
                    io:fwrite("Registration required!\n"),
                    UserName1 = get_and_parse_user_input(Sock, UserName);
                true ->
                    UserName1 = "_"
            end;
        CommandType == "login" ->
            UserName1 = signin_account();
        true ->
            io:fwrite("Invalid query!, Please Enter another command!\n"),
            UserName1 = get_and_parse_user_input(Sock, UserName)
    end,
    get_and_parse_user_input(Sock, UserName1).


register_account(Sock) ->
    % Input user-name
    {ok, [UserName]} = io:fread("\nPlease enter username: ", "~s\n"),
    % send the server request
    io:format("SELF: ~p\n", [self()]),
    ok = gen_tcp:send(Sock, [["register", ",", UserName, ",", pid_to_list(self())]]),
    io:fwrite("\nAccount Registered\n"),
    UserName.

signin_account() ->
    % Input user-name
    {ok, [UserName]} = io:fread("\nPlease enter username: ", "~s\n"),
    io:format("SELF: ~p\n", [self()]),
    io:fwrite("\nSigned in to Account\n"),
    UserName.

send_tweet(Sock,UserName) ->
    Tweet = io:get_line("\nTell me your thoughts:"),
    ok = gen_tcp:send(Sock, ["tweet", "," ,UserName, ",", Tweet]),
    io:fwrite("\nTweet Sent\n").

re_tweet(Socket, UserName) ->
    {ok, [Person_UserName]} = io:fread("\nwhose tweet do you want to re-post: ", "~s\n"),
    ok = gen_tcp:send(Socket, ["query", "," ,UserName, ",",  "3", ",", Person_UserName]),
    Tweet = io:get_line("\nWhich tweet do you want to re-post?: "),
    ok = gen_tcp:send(Socket, ["retweet", "," ,Person_UserName, ",", UserName,",",Tweet]),
    io:fwrite("\nRetweeted\n").

subscribe_to_user(Sock, UserName) ->
    SubscribeUserName = io:get_line("\nEnter the username you want to subscribe to:"),
    ok = gen_tcp:send(Sock, ["subscribe", "," ,UserName, ",", SubscribeUserName]),
    io:fwrite("\nSubscribed!\n").

query_tweet(Sock, UserName) ->
    io:fwrite("\n Querying Options:\n"),
    io:fwrite("\n 1. Mentions\n"),
    io:fwrite("\n 2. Hashtags\n"),
    io:fwrite("\n 3. Tweets from Subscribed users\n"),
    {ok, [Option]} = io:fread("\nMention the task number you intend to perform: ", "~s\n"),
    if
        Option == "1" ->
            ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",", "1", ",", UserName]);
        Option == "2" ->
            {ok, [Hashtag]} = io:fread("\nSMention the hashtag to search: ", "~s\n"),
            % Hashtag = io:get_line("\nMention the hashtag to search: "),
            ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",","2",",", Hashtag]);
        true ->
            {ok, [Sub_UserName]} = io:fread("\nWhose tweets do you want? ", "~s\n"),
            % Sub_UserName = io:get_line("\nWhose tweets do you want? "),
            ok = gen_tcp:send(Sock, ["query", "," ,UserName, ",", "3",",",Sub_UserName])
    end.

% subscribe <user_name>
% INPUT