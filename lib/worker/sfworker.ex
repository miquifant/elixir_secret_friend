defmodule SecretFriend.Worker.SFWorker do
  use GenServer
  alias SecretFriend.Core.SFList

  # ahora esta funcion devuelve {:ok, pid}
  def start_link(name) do
    GenServer.start_link(__MODULE__, {SFList.new(), nil}, name: name)
  end

  @impl GenServer
  def init(state) do
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:add_friend, friend}, {sflist, _selection} = _state) do
    new_sflist = SFList.add_friend(sflist, friend)
    {:noreply, {new_sflist, nil}}
  end

  @impl GenServer
  def handle_call(:create_selection, _from, {sflist, nil} = _state) do
    new_selection = SFList.create_selection(sflist)
    {:reply, new_selection, {sflist, new_selection}}
  end

  @impl GenServer
  def handle_call(:create_selection, _from, {_sflist, selection} = state) do
    {:reply, selection, state}
  end

  @impl GenServer
  def handle_call(:show, _from, {sflist, _selection} = state) do
    {:reply, sflist, state}
  end

end
