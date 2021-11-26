alias SecretFriend.API.SFList
alias SecretFriend.Worker.SFWorker

SFList.new(:lista1)
|> SFList.add_friend("Ramón")
|> SFList.add_friend("Javi")
|> SFList.add_friend("Miqui")

IO.puts("Loaded!! La lista es:")
IO.inspect(SFList.show(:lista1))
