defmodule SecretFriend.Worker.SFWorker do
  alias SecretFriend.Core.SFList

  def start() do
    spawn(__MODULE__, :loop, [{SFList.new(), nil}])
  end

  def loop({_sflist, _selection} = state) do
    receive do
      {:cast, msg} ->
        {:noreply, new_state} = handle_cast(msg, state)
        loop(new_state)
      {:call, from, msg} ->
        {:reply, response, new_state} = handle_call(msg, from, state)
        send(from, {:response, response})
        loop(new_state)
    end
  end

  def handle_cast({:add_friend, friend}, {sflist, _selection} = _state) do
    new_sflist = SFList.add_friend(sflist, friend)
    {:noreply, {new_sflist, nil}}
  end

  def handle_call(:create_selection, _from, {sflist, nil} = _state) do
    new_selection = SFList.create_selection(sflist)
    {:reply, new_selection, {sflist, new_selection}}
  end

  def handle_call(:create_selection, _from, {_sflist, selection} = state) do
    {:reply, selection, state}
  end

  def handle_call(:show, _from, {sflist, _selection} = state) do
    {:reply, sflist, state}
  end

end
