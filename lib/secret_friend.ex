defmodule SecretFriend do
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {SecretFriend.Worker.SFWorker, :supervised}
    ]
    opts = [strategy: :one_for_one, name: SecretFriend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
