defmodule SecretFriend.Boundary.SFListsSupervisor do
  use DynamicSupervisor
  alias SecretFriend.Worker.SFWorker

  def start_link(_args) do
    # (module, initial_argument, options)
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    # one for one: las listas son independientes. Si falla una lista reinicio solo esa.
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def create_sflist(name) do
    # child_spec: mapa id: worker, start: tupla con modulo, función arranque y argumentos.
    # o, si el worker define el child_spec: child_spec: tupla con el módulo y los args del start_link
    # { module, [arg1: val1, arg2: val2]} -> los corchetes se pueden quitar
    child_spec = %{id: SFWorker, start: {SFWorker, :start_link, [name]}}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
end
