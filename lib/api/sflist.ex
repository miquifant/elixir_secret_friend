defmodule SecretFriend.API.SFList do
  alias SecretFriend.Worker.SFWorker

  def new(name) do
    SFWorker.start_link(name)
    name
  end

  @spec add_friend(atom | pid | port | reference | {atom, atom}, any) :: any
  def add_friend(name, friend) do
    case GenServer.call(name, {:add_friend, friend}) do
      :ok -> name
      :locked -> :locked
    end
  end

  def create_selection(name) do
    GenServer.call(name, :create_selection)
  end

  def show(name) do
    alive = Process.alive?(Process.whereis(name))
    case alive do
      true ->
        GenServer.call(name, :show)
      _other -> nil
    end
  end

  #def exit(pid) do
  #  case Process.alive?(pid) do
  #    true ->
  #      Process.exit(pid, "Mas matao")
  #    _other -> nil
  #  end
  #end

  def lock?(name) do
    GenServer.call(name, :lock?)
  end

  def lock(name) do
    GenServer.cast(name, :lock)
  end
end
