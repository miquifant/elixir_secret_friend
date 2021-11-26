defmodule SecretFriend.Core.SFList do
  # Constructor. Lo llamo new pero puedo llamarlo create o como yo quiera
  # El constructor new/0 devuelve una lista vacía
  @doc """
  This creates an empty list of friends

    iex> SecretFriend.Core.SFList.new()
    []

  """
  def new, do: []

  # Función para agregar amigos a la lista. Como el orden no importa
  # los agrego por delante que es más eficiente
  def add_friend(sflist, new_friend), do: [new_friend | sflist]

  # Emparejar --> barajar y coger de dos en dos
  def create_selection(sflist) do
    sflist
    |> Enum.shuffle()
    |> gen_pairs()
  end

  # Funcion privada que encapsula la parte de barajar,
  # para poder pasarlo como leftover al chunk_every
  defp gen_pairs(sflist), do: Enum.chunk_every(sflist, 2, 1, sflist)
end
