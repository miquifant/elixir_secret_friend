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
- a las funciones como add_friend, que no esperan nada las llamaremos después `cast` (mensaje que no espera respuesta)
- y a las que sí esperan algo las llamaremos `call` (mensaje que espera respuesta).

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
Lo primero que vamos a hacer es separar el API.
(Ver commit 2)
Creamos el paquete API y dentro un módulo a la que nos llevamos las funciones del API.

Hay que cambiar el iex para que importe el de API, no el de Core, y haga new() no start().

Y cambio el spawn para que ponga __MODULE__ que hace referencia al propio módulo.

**api/sflist.ex**
```
defmodule SecretFriend.API.SFList do
  alias SecretFriend.Worker.SFWorker

  def new(), do: SFWorker.start()

  def add_friend(pid, friend) do
    send(pid, {:add_friend, friend})
  end

  def create_selection(pid) do
    send(pid, {:create_selection, self()})
    receive do
      {:reply_create_selection, selection} ->
        selection
      _other -> nil
    end
  end

  def show(pid) do
    alive = Process.alive?(pid)
    case alive do
      true ->
        send(pid, {:show, self()})
        receive do
          {:reply_show, sflist} ->
            sflist
          _other ->
            nil
        end
      _other -> nil
    end
  end

  def exit(pid) do
    case Process.alive?(pid) do
      true ->
        Process.exit(pid, "Mas matao")
      _other -> nil
    end
  end
end
```
.iex.exs
```
alias SecretFriend.API.SFList
alias SecretFriend.Worker.SFWorker

sflist = SFList.new()
SFList.add_friend(sflist, "Ramón")
SFList.add_friend(sflist, "Javi")
SFList.add_friend(sflist, "Miqui")

IO.puts("Loaded!! La lista es:")
IO.inspect(sflist)
```

Ahora además le vamos a cambiar la función add_friend para que devuelva el PID y así poder concatenar.
```
  def add_friend(pid, friend) do
    send(pid, {:add_friend, friend})
    pid
  end
```
el .iex.ex quedaría:
```
alias SecretFriend.API.SFList
alias SecretFriend.Worker.SFWorker

sflist =
  SFList.new()
  |> SFList.add_friend("Ramón")
  |> SFList.add_friend("Javi")
  |> SFList.add_friend("Miqui")

IO.puts("Loaded!! La lista es:")
IO.inspect(sflist)
```
---
analizamos el loop:
- parece que tuviéramos tres funciones diferentes.
- dos tipos distintas.
  - las que cambian estado
  - las que cambian estado y responden al llamante

Hacemos una función handle_cast para las que no responden
y una handle_call para las otras.

En las calls saco el from del mensaje, a un segundo param.
Y el estado, que estábamos cambiando en las funciones, tenemos que recibirlo como param.
El estado lo modelamos como una tupla {sflist, selection}
y a esa tupla la llamamos tambien state.
```
{sflist, selection} = state
```
Los que no vayamos a usar le podemos poner guión bajo.
Pero dejamos todos los handlers como:
```
handle_cast(msg, state)
handle_call(msg, from, state)
```
Algo tipo:
```
  def loop(sflist, selection) do
    receive do
    end
  end

  def handle_cast({:add_friend, friend}, {sflist, _selection} = _state) do
    sflist = SFList.add_friend(sflist, friend)
    loop(sflist, nil)
  end

  def handle_call(:create_selection, from, {sflist, selection} = _state) do
    case selection do
      nil ->
        new_selection = SFList.create_selection(sflist)
        send(from, {:reply_create_selection, new_selection})
        loop(sflist, new_selection)

      existing_selection ->
        send(from, {:reply_create_selection, existing_selection})
        loop(sflist, existing_selection)
    end

    def handle_call(:show, from, {sflist, selection} = _state) do
      send(from, {:reply_show, sflist})
      loop(sflist, selection)
    end
  end
```
Mis funciones cast cogen el estado, lo manipulan y devuelven el nuevo estado:
"noreply" y el nuevo estado.
```
  def handle_cast({:add_friend, friend}, {sflist, _selection} = _state) do
    new_sflist = SFList.add_friend(sflist, friend)
    loop(new_sflist, nil)
  end
```
Lo cambiamos para devolverlo en tupla parecido a la entrada
```
{:noreply, {new_sflist, new_selection}}

handle_cast(msg, state) -> {:noreply, new_state}
```
Las funciones call, también nos calzamos la llamada al loop, e incluso el send.
Aqui el retorno es "reply", lo que hay que responder, y el nuevo estado.
```
{:reply, response, {new_sflist, new_selection}}

handle_call(msg, from, state) -> {:reply, response, new_state}
```
quedaría:
```
  def handle_call(:create_selection, _from, {sflist, selection} = _state) do
    case selection do
      nil ->
        new_selection = SFList.create_selection(sflist)
        {:reply, new_selection, {sflist, new_selection}}

      existing_selection ->
        {:reply, existing_selection, {sflist, existing_selection}}
    end
  end
```
O mejor, cuando el estado no haya cambiado, usamos state.
```
  def handle_call(:create_selection, _from, {sflist, selection} = state) do
    case selection do
      nil ->
        new_selection = SFList.create_selection(sflist)
        {:reply, new_selection, {sflist, new_selection}}

      existing_selection ->
        {:reply, existing_selection, state}
    end
  end
```
Así se ve que la segunda rama NO CAMBIA el estado.
En el último caso es donde mejor se ve qué hace:
```
  def handle_call(:show, _from, {sflist, _selection} = state) do
    {:reply, sflist, state}
  end
```
Solo lee la lista, la selección no, y devuelve state, o sea, que no altera el estado.
---
Ahora mira que handle_call(:create_selection,...) está haciendo pattern matching.
La podemos dividir en dos funciones.
```
  def handle_call(:create_selection, _from, {sflist, nil} = _state) do
    new_selection = SFList.create_selection(sflist)
    {:reply, new_selection, {sflist, new_selection}}
  end

  def handle_call(:create_selection, _from, {_sflist, selection} = state) do
    {:reply, selection, state}
  end
```
Ahora solo hay que integrar esto en el loop.
Decimos que puede recibir casts y calls.
- cast msg
- call from msg
```
  def loop({_sflist, _selection} = state) do
    receive do
      {:cast, msg} ->
        handle_cast(msg, state)
      {:call, from, msg} ->
        handle_call(msg, from, state)
    end
  end
```
Ahí tenemos la llamada, nos falta la respuesta.
```
  def loop({_sflist, _selection} = state) do
    receive do
      {:cast, msg} ->
        {:noreply, new_state} = handle_cast(msg, state)
        loop(new_state)
      {:call, from, msg} ->
        {:reply, response, new_state} = handle_call(msg, from, state)
        send(from, response)
        loop(new_state)
    end
  end
```

Con esto, la parte del servicio está, ahora hay que cambiar el API.
```
# Cambio
  def add_friend(pid, friend) do
    send(pid, {:add_friend, friend})
    pid
  end
  def create_selection(pid) do
    send(pid, {:create_selection, self()})
    receive do
      {:reply_create_selection, selection} ->
        selection
      _other -> nil
    end
  end
# por
  def add_friend(pid, friend) do
    send(pid, {:cast, {:add_friend, friend}})
    pid
  end

  def create_selection(pid) do
    send(pid, {:call, self(), :create_selection})
    receive do
      {:response, selection} ->
        selection
      _other -> nil
    end
  end
```
Y ahora vemos que los receives están duplicados, porque siempre recibo {:response, response}}
```
def create_selection(pid) do
    send(pid, {:call, self(), :create_selection})
    receive do
      {:response, selection} ->
        selection
      _other -> nil
    end
  end

  def show(pid) do
    alive = Process.alive?(pid)
    case alive do
      true ->
        send(pid, {:call, self(), :show})
        receive do
          {:response, sflist} ->
            sflist
          _other ->
            nil
        end
      _other -> nil
    end
  end
```
Así que lo cambio por:
```
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
```
Y hay que cambiar el arranque:
```
De:
  def start() do
    spawn(__MODULE__, :loop, [SFList.new(), nil])
  end

A:
  def start() do
    spawn(__MODULE__, :loop, [{SFList.new(), nil}])
  end

Porque loop ahora solo tiene un argumento, que es una tupla
```
En este punto hago el commit 2.
Los siguientes irán al commit 3.

El último cambio es meter el GenServer.

La lógica del loop es genérica.
```
def loop({_sflist, _selection} = state) do
    receive do
      {:cast, msg} ->
        {:noreply, new_state} = handle_cast(msg, state)
        loop(new_state)
      {:call, from, msg} ->
        {:reply, response, new_state} = handle_call(msg, from, state)
        send(from, {:response, response})
        loop(new_state)
    end
  end
```
- Me calzo ese bucle y hago use GenServer (es como "extender" o hacer mixing de GenServer. Me traigo su código y lo amplio)
- A start lo llamaremos start_link
- En vez de hacer el spawn haremos un GenServer start_link
- Ya no nos referimos a las listas por su pid sino que le vamos a dar un nombre
```
Cambio:
  def start() do
    spawn(__MODULE__, :loop, [{SFList.new(), nil}])
  end
  def loop ...

Por:
  def start_link(name) do
                                   # << state inicial <<
    GenServer.start_link(__MODULE__, {SFList.new(), nil}, name: name)
  end
```
Y podemos añadir una anotación a las funciones handle_call y handle_cast 
para que quede claro que estamos sobreescribiendo funciones de genServer
```
@impl GenServer
```
Podemos añadir también una implementación del init de GenServer
Ejemplo sencillo:
```
@impl GenServer
def init(state) do
  {:ok, state}
end
```
Eso sería la parte del server. La del API:
- llamo a start_link en vez de start, pasándole el nombre
- cambio los pids por names
- quito el handle_rsponse que ya no lo hago yo
- quito los sends y hago llamadas a GenServer (que ya no pasan ni self() ni :cast / :call)
- cambio el uso en el .ies.ex
```
alias SecretFriend.API.SFList
alias SecretFriend.Worker.SFWorker

SFList.new(:lista1)
|> SFList.add_friend("Ramón")
|> SFList.add_friend("Javi")
|> SFList.add_friend("Miqui")

IO.puts("Loaded!! La lista es:")
IO.inspect(SFList.show(:lista1))

```