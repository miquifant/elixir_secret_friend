alias SecretFriend.API.SFList
alias SecretFriend.Worker.SFWorker

sflist =
  SFList.new()
  |> SFList.add_friend("Ramón")
  |> SFList.add_friend("Javi")
  |> SFList.add_friend("Miqui")

IO.puts("Loaded!! La lista es:")
IO.inspect(SFList.show(sflist))
