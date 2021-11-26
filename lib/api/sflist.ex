defmodule SecretFriend.API.SFList do
  alias SecretFriend.Worker.SFWorker

  def new(), do: SFWorker.start()

  @spec add_friend(atom | pid | port | reference | {atom, atom}, any) :: any
  def add_friend(pid, friend) do
    send(pid, {:cast, {:add_friend, friend}})
    pid
  end

  def create_selection(pid) do
    send(pid, {:call, self(), :create_selection})
    handle_response()
  end

  def show(pid) do
    alive = Process.alive?(pid)
    case alive do
      true ->
        send(pid, {:call, self(), :show})
        handle_response()
      _other -> nil
    end
  end

  defp handle_response() do
    receive do
      {:response, response} -> response
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
end
