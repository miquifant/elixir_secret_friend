defmodule SecretFriend do
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {SecretFriend.Boundary.SFListsSupervisor, :noargs}
    ]

    :ets.new(:sflist_cache, [:named_table, :set, :public])

    opts = [strategy: :one_for_one, name: SecretFriend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
