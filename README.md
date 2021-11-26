# ElixirSecretFriend

## work log

### Creación proyecto

Esto lo he creado desde el terminal del vscode con el proyecto elixir-sessions abierto, haciendo
```
mix new elixir_secret_friend
```
Pero luego lo he sacado fuera y he copiado la .devcontainers del otro proyecto aqui.

### Desarrollo

Creo una carpeta lib/core y meto un sflist.ex

El nombre de la aplicación será la raíz, aunque el nombre de la carpeta no importa.
En mi caso la carpeta se llama elixir_secret_friend, pero internamente será SecretFriend solo.

Así que el paquete es SecretFriend.Core

Ver código con comentarios para ver cómo está picado.

### Tests

A continuación en la carpeta test meto un sflist_test.exs.
Importante que el nombre termine en _test para que se ejecute al hacer mix test

### REPL

- Se puede pipear la salida de la ejecución anterior
o hacer referencia con la función `v` 
```
iex(2)> SFList.new
[]
iex(3)> |> SFList.add_friend("Ramon")
["Ramon"]
iex(4)> |> SFList.add_friend("Javi") 
["Javi", "Ramon"]
iex(5)> |> SFList.add_friend("Miqui")
["Miqui", "Javi", "Ramon"]
iex(6)> sflist = v(5)
["Miqui", "Javi", "Ramon"]
iex(7)> sflist 
["Miqui", "Javi", "Ramon"]
```
- Se puede recargar el proyecto con r(SFList)
- creo un fichero .iex.exs en la raíz del proyecto,
para que cada vez que entre al REPL se ejecute y facilitarme la vida.
```
alias SecretFriend.Core.SFList

sflist =
  SFList.new()
  |> SFList.add_friend("Ramón")
  |> SFList.add_friend("Javi")
  |> SFList.add_friend("Miqui")

IO.puts("Loaded!! La lista es:")
IO.inspect(sflist)
```

### Sacapuntas

Una vez implementado el core, vemos que si ejecuto N veces la selección
se me genera cada vez distinta.
```
Interactive Elixir (1.12.3) - press Ctrl+C to exit (type h() ENTER for help)
Loaded!! La lista es:
["Miqui", "Javi", "Ramón"]
iex(1)> SFList.create_selection(sflist)
[["Ramón", "Miqui"], ["Miqui", "Javi"], ["Javi", "Ramón"]]
iex(2)> SFList.create_selection(sflist)
[["Javi", "Miqui"], ["Miqui", "Ramón"], ["Ramón", "Javi"]]
iex(3)> SFList.create_selection(sflist)
[["Javi", "Miqui"], ["Miqui", "Ramón"], ["Ramón", "Javi"]]
iex(4)> SFList.create_selection(sflist)
[["Miqui", "Ramón"], ["Ramón", "Javi"], ["Javi", "Miqui"]]
```

Quiero que solo cambie si meto amigos nuevos.

¿Cómo puedo mantener la lista ya hecha si no hay clases ni objetos?

Se crea un proceso alrededor de nuestro estado.

* `spawn` crea un proceso, ejecuta una función y muere
* `receive` lee un mensaje entrante
* `send` envía un mensaje
```
iex> :timer.sleep(1) # Ojo! no es Timer porque es Erlang, no elixir
iex(NN)> spawn(fn -> :timer.sleep(30_000) end)
#PID<x.x.x> # devuelve inmediatamente el PID aunque el proceso estará 30" frito
iex> pid = v(NN) --> si no pongo (NN) coge el anterior.
iex> Process.alive?(pid)
iex> Process.info(pid)
```
Vemos que durante 30" responde true y luego false.
Y el info pasa de devolver cosas a nil
Cada proceso tiene su propio heap, su propio gc,...

Eso es un proceso cuyo resultado me la trae al pairo, pero si quiero algo util
necesito `send`.
```
iex(1)> self()
#PID<0.144.0> <---- PID del proceso actual: El REPL
```
Me voy a mandar un mensaje: Ej.: Tupla (el primer elemento un identif. del mensaje, y luego el propio mensaje)
```
iex(2)> send(self(), {:hello, "world"})
{:hello, "world"} <---- eso es el resultado del send, no el mensaje
```
Para ver el mensaje hago flush
```
iex(3)> flush
{:hello, "world"} 
:ok
iex(4)> flush
:ok
```
(eso es para debug. normalmente los leo con receive)
```
iex(5)> send(self(), {:hello, "world"})
{:hello, "world"}
iex(6)> receive do
...(6)>   {:hello, msg} -> IO.puts("Hello #{msg}!!")
...(6)> end
Hello world!!
:ok
```
ahí he leido UN mensaje.
Cada vez que ejecute lee uno.
Y si no hay más mensajes se queda esperando.
```
iex(7)> send(self(), {:hello, "world"})             
{:hello, "world"}
iex(8)> send(self(), {:hello, "world2"})            
{:hello, "world2"}
iex(9)> receive do                                  
...(9)>   {:hello, msg} -> IO.puts("Hello #{msg}!!")
...(9)> end                                         
Hello world!!
:ok
iex(10)> receive do                                  
...(10)>   {:hello, msg} -> IO.puts("Hello #{msg}!!")
...(10)> end                                         
Hello world2!!
:ok
iex(11)> receive do                                  
...(11)>   {:hello, msg} -> IO.puts("Hello #{msg}!!")
...(11)> end                                         
<--------------------------------- SE QUEDA ESCUCHANDO
```
Hacemos un modulo `sfworker` para implementar un "servicio" que crea y gestiona
las listas de amigos. Y nos vamos a comunicar con ella con mensajes:

- crea una lista
- agrega un amigo a la lista
- haz una selección
- ...

Ver modulo. Creamos una función que hace el bucle con el receive.
El bucle lo hacemos con una llamada a la función como última linea.
Eso generará el bucle.
```
def loop()
  receive do
    ...
  end
  loop()
end
```
Aqui tenemos un problema y es que muchos de los mensajes requieren un sflist.
Lo ponemos como parametro de loop() y lo modifican mis mensajes...
EL otro estado es la selección, que también habrá que pasarlo.
Y necesitamos, otra funcion para arrancar. Lo hacemos con un spawn(módulo, función, argumentos) --> notación MFA.
```
spawn(SecretFroend.Worker.SFWorker, :loop, [nil, nil])
```
Lo implementamos asi
```
defmodule SecretFriend.Worker.SFWorker do
  alias SecretFriend.Core.SFList

  def start() do
    spawn(SecretFriend.Worker.SFWorker, :loop, [nil, nil])
  end

  def loop(sflist, selection) do
    receive do
      :new ->
        sflist = SFList.new()
        loop(sflist, selection)
      {:add_friend, friend} ->
        sflist = SFList.add_friend(sflist, friend)
        loop(sflist, selection)
      :create_selection ->
        selection = SFList.create_selection(sflist)
        loop(sflist, selection)
      :show ->
        IO.inspect(sflist)
        loop(sflist, selection)
    end
  end
end
```
Y ejecutar asi:
```
iex(1)> SFWorker.start
#PID<0.146.0>
iex(2)> SFWorker.start
#PID<0.148.0>
iex(3)> [lista1, lista2] = [v(1), v(2)]
[#PID<0.146.0>, #PID<0.148.0>]

iex(6)> send(lista1, :new)
:new
iex(7)> send(lista1, :show)
[]
:show
iex(8)> send(lista2, :show)
nil
:show
iex(9)> send(lista1, {:add_friend, :ramon})
{:add_friend, :ramon} 
iex(10)> send(lista1, :show)                
[:ramon]
:show
iex(11)> send(lista1, {:add_friend, :lolo}) 
{:add_friend, :lolo}
iex(12)> send(lista1, {:add_friend, :juan})
{:add_friend, :juan}
iex(13)> send(lista1, :create_selection)   
:create_selection
```
No me está contestando los send. Es que hay un print y por eso veo cosas.
Y la selección, no devuelve nada.
Cuando yo quiera que un mensaje me de una respuesta le pasará mi PID para que me mande un mensaje de vuelta con el resultado de la operación.
Cambiamos la implementación de create_selection:
```
    {:create_selection, from} ->
        selection = SFList.create_selection(sflist)
        send(from, {:reply, selection})
        loop(sflist, selection)
```
Como es un coñazo trabajar así, nos creamos un API.

- En Start hago ya el new
- Creo funciones a las que se llamarán en vez de hacer `send(...)`
- Las funciones que sean síncronas, en su implementación harán receive
```
defmodule SecretFriend.Worker.SFWorker do
  alias SecretFriend.Core.SFList

  def start() do
    spawn(SecretFriend.Worker.SFWorker, :loop, [SFList.new(), nil])
  end

  def loop(sflist, selection) do
    receive do
      {:add_friend, friend} ->
        sflist = SFList.add_friend(sflist, friend)
        loop(sflist, selection)

      {:create_selection, from} ->
        case selection do
          nil ->
            new_selection = SFList.create_selection(sflist)
            send(from, {:reply_create_selection, new_selection})
            loop(sflist, new_selection)

          existing_selection ->
            send(from, {:reply_create_selection, existing_selection})
            loop(sflist, existing_selection)
        end

      {:show, from} ->
        send(from, {:reply_show, sflist})
        loop(sflist, selection)
    end
  end

  def add_friend(pid, friend) do
    send(pid, {:add_friend, friend})
  end

  def create_selection(pid) do
    send(pid, {:create_selection, self()})
    receive do
      {:reply_create_selection, selection} ->
        selection
      _other ->
        nil
    end
  end

  def show(pid) do
    send(pid, {:show, self()})
    receive do
      {:reply_show, sflist} ->
        sflist
      _other ->
        nil
    end
  end
end
```
- a las funciones como add_friend, que no esperan nada las llamaremos después `cast`
- y a las que sí esperan algo las llamaremos `call`.

Ahora lo uso sin hacer sends sino llamando a su API:
```
iex(1)> lista1 = SFWorker.start
#PID<0.160.0>
iex(2)> SFWorker.add_friend(lista1, :ramon)
{:add_friend, :ramon} 
iex(3)> SFWorker.add_friend(lista1, :lolo) 
{:add_friend, :lolo}
iex(4)> SFWorker.add_friend(lista1, :juan)
{:add_friend, :juan}
iex(5)> SFWorker.show(lista1)
[:juan, :lolo, :ramon]
iex(6)> SFWorker.create_selection(lista1)
[[:juan, :ramon], [:ramon, :lolo], [:lolo, :juan]]
iex(7)> SFWorker.create_selection(lista1)
[[:juan, :ramon], [:ramon, :lolo], [:lolo, :juan]]
iex(8)> SFWorker.create_selection(lista1)
[[:juan, :ramon], [:ramon, :lolo], [:lolo, :juan]]
iex(9)> SFWorker.create_selection(lista1)
[[:juan, :ramon], [:ramon, :lolo], [:lolo, :juan]]
iex(10)> SFWorker.create_selection(lista1)
[[:juan, :ramon], [:ramon, :lolo], [:lolo, :juan]]
iex(11)> SFWorker.create_selection(lista1)
[[:juan, :ramon], [:ramon, :lolo], [:lolo, :juan]]
```
Siempre devuelve la misma selección, porque solo la ha hecho una vez
Pero ahora si añado un amigo, la selección sigue siendo sin él.
Hay que invalidar la selección al hacer add_friend.
```
...
  def loop(sflist, selection) do
    receive do
      {:add_friend, friend} ->
        sflist = SFList.add_friend(sflist, friend)
        loop(sflist, nil)
        ...

```
Echándole un ojo al loop() vemos cómo está creciendo:
```
  def loop(sflist, selection) do
    receive do
      {:add_friend, friend} ->
        sflist = SFList.add_friend(sflist, friend)
        loop(sflist, nil)

      {:create_selection, from} ->
        case selection do
          nil ->
            new_selection = SFList.create_selection(sflist)
            send(from, {:reply_create_selection, new_selection})
            loop(sflist, new_selection)

          existing_selection ->
            send(from, {:reply_create_selection, existing_selection})
            loop(sflist, existing_selection)
        end

      {:show, from} ->
        send(from, {:reply_show, sflist})
        loop(sflist, selection)
    end
  end
```
Si ahora quisiera ponerle una condición para que, por ejemplo, al hacer `add_friend` mirase el nombre y si me pasas p.e. Tadeo no lo añada,... vemos que hay que seguir haciendo más y más cambios a ese `loop`. Que no escala.

Esta no es la forma de hacer las cosas. Únicamente es una explicación para ver qué hay por debajo y que resulte menos "magia" lo que viene a continuación:
---

¿Cómo podemos organizar el código para que tenga menos boiler plate?
¿Cómo simplificamos o reducimos la función loop?
¿Cómo hacemos para que sea más fácil añadir nuevos mensajes?

Si te fijas, la función se parece mucho a una función con distintos pattern-matches
```
  def loop(sflist, selection) do
    receive do
      {:add_friend, friend} ->
        sflist = SFList.add_friend(sflist, friend)
        loop(sflist, nil)

      {:create_selection, from} ->
        case selection do
          nil ->
            new_selection = SFList.create_selection(sflist)
            send(from, {:reply_create_selection, new_selection})
            loop(sflist, new_selection)

          existing_selection ->
            send(from, {:reply_create_selection, existing_selection})
            loop(sflist, existing_selection)
        end

      {:show, from} ->
        send(from, {:reply_show, sflist})
        loop(sflist, selection)

      :end ->
        nil
    end
  end
```
Lo primero que vamos a hacer es separar el API