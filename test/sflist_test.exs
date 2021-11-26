defmodule SFListTest do
  # Esto le da a este módulo la capacidad de ser un test
  use ExUnit.Case
  alias SecretFriend.Core.SFList
  # Esto es para que ejecute los tests de la documentación del módulo
  doctest SFList

  test "SFList creation" do
    assert SFList.new() == []
  end

  test "Add friends" do
    sflist =
      SFList.new()
      |> SFList.add_friend("Ramón")
      |> SFList.add_friend("Javi")
      |> SFList.add_friend("Miqui")

    assert sflist == ["Miqui", "Javi", "Ramón"]
  end

  test "Create selection" do
    selection =
      SFList.new()
      |> SFList.add_friend("Ramón")
      |> SFList.add_friend("Javi")
      |> SFList.add_friend("Miqui")
      |> SFList.create_selection()

    # Compruebo que tengo 3 empàrejamientos
    assert length(selection) == 3

    # Compruebo que para todos los elementos de selección cumplen una condición
    # (que son dos personas distintas en cada par)
    assert Enum.all?(selection, fn e -> (Enum.at(e, 0) != Enum.at(e, 1)) end)
    # Esta es la misma validación pero cambiando la notación de lambda
    assert Enum.all?(selection, &(Enum.at(&1, 0) != Enum.at(&1, 1)))

    # Comprobar que si me quedo el primer elemento de cada par y
    # cuento los únicos me debe dar 3
    # para que cada persona solo regale a uno.
    assert length(Enum.uniq_by(selection, &Enum.at(&1, 0))) == 3
    # Que no haya nadie que recibe más de un reglao
    assert length(Enum.uniq_by(selection, &Enum.at(&1, 1))) == 3
  end
end
