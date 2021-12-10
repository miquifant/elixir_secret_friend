defmodule SecretFriend.Worker.SFWorker do
  use GenServer
  alias SecretFriend.Core.SFList

  # ahora esta funcion devuelve {:ok, pid}
  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  @impl GenServer
  def init(name) do
    case :ets.lookup(:sflist_cache, name) do
      [] ->
        {:ok, %{name: name, sflist: SFList.new(), selection: nil, lock: false}}
      [{^name, state}] ->
        {:ok, state}
    end
  end

  @impl GenServer
  def handle_cast(:lock, %{name: name} = state) do
    new_state = %{state | lock: true}
    :ets.insert(:sflist_cache, {name, new_state})
    {:noreply, %{new_state | lock: true}}
  end

  @impl GenServer
  def handle_call(:create_selection, _from, %{name: name, sflist: sflist, selection: nil} = state) do
    new_selection = SFList.create_selection(sflist)
    new_state = %{state | selection: new_selection}
    :ets.insert(:sflist_cache, {name, new_state})
    {:reply, new_selection, new_state}
  end

  @impl GenServer
  def handle_call(:create_selection, _from, %{selection: selection} = state) do
    {:reply, selection, state}
  end

  @impl GenServer
  def handle_call(:show, _from, %{sflist: sflist} = state) do
    {:reply, sflist, state}
  end

  @impl GenServer
  def handle_call(:lock?, _from, %{lock: lock} = state) do
    {:reply, lock, state}
  end

  @impl GenServer
  def handle_call({:add_friend, friend}, _from, %{sflist: sflist, lock: false} = state) do
    new_sflist = SFList.add_friend(sflist, friend)
    {:reply, :ok, %{state | sflist: new_sflist, selection: nil}}
  end

  @impl GenServer
  def handle_call({:add_friend, _friend}, _from, %{lock: true} = state) do
    {:reply, :locked, state}
  end
end
