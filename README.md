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
---
Vamos a añadir un mensaje "lock" para hacer que a la lista no se puedan añadir más amigos.
Necesitamos ampliar el estado.
{lista, selección, bloqueado}
El estado se está convirtiendo en un asquete. Lo convertimos en un mapa.
%{sflist: lista, selection: seleccion, lock: bloqueado}
```
  def start_link(name) do
    GenServer.start_link(__MODULE__, %{sflist:SFList.new(), selection: nil, lock: false}, name: name)
  end
```
En los sitios donde tenía una tupla ahora hay que poner un diccionario, y ya los _unused podemos omitirlos.
Hay una syntax para añadir elementos a una diccionario.
%{diccionario | campo: nuevo_valor}
```
  @impl GenServer
  def handle_cast({:add_friend, friend}, %{sflist: sflist} = state) do
    new_sflist = SFList.add_friend(sflist, friend)
    {:noreply, %{state | sflist: new_sflist, selection: nil}}
  end

  @impl GenServer
  def handle_call(:create_selection, _from, %{sflist: sflist, selection: nil} = state) do
    new_selection = SFList.create_selection(sflist)
    {:reply, new_selection, %{state | selection: new_selection}}
  end

  @impl GenServer
  def handle_call(:create_selection, _from, %{selection: selection} = state) do
    {:reply, selection, state}
  end

  @impl GenServer
  def handle_call(:show, _from, %{sflist: sflist} = state) do
    {:reply, sflist, state}
  end
```

Tras el refactor, debe seguir funcionando:
```
# SFList.new(:lista1)
# |> SFList.add_friend("Ramón")
# |> SFList.add_friend("Javi")
# |> SFList.add_friend("Miqui")
iex(1)> SFList.create_selection(:lista1)
[["Javi", "Ramón"], ["Ramón", "Miqui"], ["Miqui", "Javi"]]
```
Ahora ya podemos implementar la funcionalidad de `lock`
Añadir al API una función lock? que devuelva si está bloqueada la lista.
Cambiar en el servidor para que me devuelva el valor.
```
# API
  def lock?(name) do
    GenServer.call(name, :lock?)
  end

# GenServer
  @impl GenServer
  def handle_call(:lock?, _from, %{lock: lock} = state) do
    {:reply, lock, state}
  end

# call
iex(1)> SFList.lock?(:lista1)      
false
```
Y ahora podríamos hacer la función de bloqueo de lista.
- Primero implementar el mensaje imperativo lock,
- y después tocar add_friend para que no añada a listas locked
Recordar que los handle_cast deben estar juntos todos, y los handle_call.
Y recordar que el orden en que se ponen las funciones importa.

Implementamos el lock:
```
#api
  def lock(name) do
    GenServer.cast(name, :lock)
  end

# worker
  @impl GenServer
  def handle_cast(:lock, state) do
    {:noreply, %{state | lock: true}}
  end

iex(1)> SFList.lock?(:lista1)
false
iex(2)> SFList.lock(:lista1) 
:ok
iex(3)> SFList.lock?(:lista1)
true
```
Modificamos el add_friend:
Si le ponemos en el pattern matching que el state incluya %{sflist: sflist, lock: false} = state
hacemos que add_friend solo funcione si no está bloqueada.
Pero tendríamos que cambiar el cast por call para responder que no se puede o si se hizo.
En este punto se piña, porque no tendríamos implementado cuando lock es false (no hay un handle_cast que maneje ese estado)
```
iex(1)> SFList.lock?(:lista1)
false
iex(2)> SFList.lock(:lista1) 
:ok
iex(3)> SFList.add_friend(:lista1, :manolooo)
:lista1
iex(4)> 
08:30:43.310 [error] GenServer :lista1 terminating
** (FunctionClauseError) no function clause matching in SecretFriend.Worker.SFWorker.handle_cast/2
    (elixir_secret_friend 0.1.0) lib/worker/sfworker.ex:16: SecretFriend.Worker.SFWorker.handle_cast({:add_friend, :manolooo}, %{lock: true, selection: nil, sflist: ["Miqui", "Javi", "Ramón"]})
    (stdlib 3.16.1) gen_server.erl:695: :gen_server.try_dispatch/4
    (stdlib 3.16.1) gen_server.erl:771: :gen_server.handle_msg/6
    (stdlib 3.16.1) proc_lib.erl:226: :proc_lib.init_p_do_apply/3
Last message: {:"$gen_cast", {:add_friend, :manolooo}}
State: %{lock: true, selection: nil, sflist: ["Miqui", "Javi", "Ramón"]}
** (EXIT from #PID<0.159.0>) shell process exited with reason: an exception was raised:
    ** (FunctionClauseError) no function clause matching in SecretFriend.Worker.SFWorker.handle_cast/2
        (elixir_secret_friend 0.1.0) lib/worker/sfworker.ex:16: SecretFriend.Worker.SFWorker.handle_cast({:add_friend, :manolooo}, %{lock: true, selection: nil, sflist: ["Miqui", "Javi", "Ramón"]})
        (stdlib 3.16.1) gen_server.erl:695: :gen_server.try_dispatch/4
        (stdlib 3.16.1) gen_server.erl:771: :gen_server.handle_msg/6
        (stdlib 3.16.1) proc_lib.erl:226: :proc_lib.init_p_do_apply/3
```
Hay que hacer una versión cuando el lock es true, aunque no haga nada.
```
  @impl GenServer
  def handle_cast({:add_friend, friend}, %{sflist: sflist, lock: false} = state) do
    new_sflist = SFList.add_friend(sflist, friend)
    {:noreply, %{state | sflist: new_sflist, selection: nil}}
  end

  @impl GenServer
  def handle_cast({:add_friend, _friend}, %{lock: true} = state) do
    {:noreply, state}
  end

  # Que, por pattern matching, no haría falta que dijera que lock: true, ya que es el único caso que queda. Solo que es menos claro al leerlo y tiene que estar la segunda, pero las dos valen
  @impl GenServer
  def handle_cast({:add_friend, _friend}, state) do
    {:noreply, state}
  end
```
Vemos que ya no hace nada el add_friend en listas bloqueadas:
```
iex(1)> SFList.show(:lista1)
["Miqui", "Javi", "Ramón"]
iex(2)> SFList.lock?(:lista1)
false
iex(3)> SFList.lock(:lista1) 
:ok
iex(4)> SFList.add_friend(:lista1, :manoloooo) |> SFList.show()
["Miqui", "Javi", "Ramón"]
```
Ahora cambiamos el cast a call para devolver el error, y cambio el API para que haga
`:ok -> name`
`:locked -> :locked`
o mejor:
```
  def add_friend(name, friend) do
    case GenServer.call(name, {:add_friend, friend}) do
      :ok -> {:ok, name}
      :locked -> {:error, :locked}
    end
  end
```
El servicio queda:
```
TO DO
```

--

# Supervisor
Y si el servicio revienta? 
Un supervisor se encargará de re-arrancar o hacer lo que yo le diga con el proceso.

Para ellos vamos a dejar de trabajar con iex y definir una aplicación.

Cuando creamos el proyecto hicimos mix new y le dimos un nombre.
Si le pongo la opción --sup me crea un fichero application.ex
Es una aplicación OTP.
```
defmodule XXXXX.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: XXXXX.Worker.start_link(arg)
      # {XXXXX.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: XXXXX.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

```
children es todas las cosas que quiero que se arranquen cuando arranco la aplicación.
`{modulo, args}` --> llamará al start_link de ese módulo pasándole esos argumentos.
Este es el supervisor "padre".
Ejemplo:
```
defmodule SecretFriend do
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {SecretFriend.Worker.SFWorker, :supervised}
      # puede haber varios children pero no del mismo tipo.
      # lo podrá hacer con un dynamic supervisor
    ]
    ...
  end
end
```
Y a continuación lo arrancamos diciendo la estrategia de rearranque:
- one_for_one: si muere uno se rearranca solo él
- one_for_all: si muere uno se rearranca él y todos los que están tras él en la lista
```
  @impl Application
  def start(_type, _args) do
    children = [
      {SecretFriend.Worker.SFWorker, :supervised}
    ]
    opts = [strategy: :one_for_one, name: SecretFriend.Supervisor]
    Supervisor.start_link(children, opts)
  end
```
En el proyecto con --sup añadió tb:
```
# Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {XXXX.Application, []}
    ]
  end
```
Lo añadimos:
```
  def application do
    [
      mod: {SecretFriend, []},
      extra_applications: [:logger]
    ]
  end
```
Aqui, SecretFriend es mi aplicación (el módulo que hemos convertido en aplicación).
Este proyecto solo levantaría esa aplicación, pero podría levantar las que quisiera.
```
iex(1)> Supervisor.which_children(SecretFriend.Supervisor)
[
  {SecretFriend.Worker.SFWorker, #PID<0.147.0>, :worker,
   [SecretFriend.Worker.SFWorker]}
]
```
Interactúo con el proceso:
```
iex(2)> SFList.show(:supervised)
[]
iex(3)> SFList.add_friend(:supervised, :pepe)
:supervised
iex(4)> SFList.show(:supervised)             
[:pepe]
iex(5)> 
```
Si me calzo el :lista1 se lleva la consola por delante
```
iex(6)> Process.whereis(:lista1)
#PID<0.149.0>
iex(7)> |> Process.exit(:boom)
** (EXIT from #PID<0.148.0>) shell process exited with reason: :boom

Interactive Elixir (1.12.3) - press Ctrl+C to exit (type h() ENTER for help)
Loaded!! La lista es:
["Miqui", "Javi", "Ramón"]
iex(1)> 
```
Si me calzo el supervised no, pero se rearranca:
```
iex(1)> Process.whereis(:supervised)
#PID<0.147.0>
iex(2)> |> Process.exit(:boom)      
true
```
Lo único malo es que pierdo el estado, pero sigo pudiendo trabajar con el proceso.
```
iex(3)> SFList.add_friend(:supervised, :pepe)
:supervised
iex(4)> SFList.show(:supervised)             
[:pepe]
iex(5)> Process.whereis(:supervised)         
#PID<0.161.0>
iex(6)> |> Process.exit(:boom)               
true
iex(7)> SFList.show(:supervised)             
[]
```
Si quiero mantener el estado lo metemos en algún sitio.
En la VM erlang y la lib stand existen dos bbdd:
- una clave valor
- una no-sql con tablas y campos consultables

La clave valor es `ets`. Es de Erlang.
Se usa con `:ets.`
Lo vemos en la prox sesión.

Vamos a crear un ejecutable de la aplicación con `mix release`
```
$ mix release
* assembling elixir_secret_friend-0.1.0 on MIX_ENV=dev
* skipping runtime configuration (config/runtime.exs not found)
* skipping elixir.bat for windows (bin/elixir.bat not found in the Elixir installation)
* skipping iex.bat for windows (bin/iex.bat not found in the Elixir installation)

Release created at _build/dev/rel/elixir_secret_friend!

    # To start your system
    _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend start

Once the release is running:

    # To connect to it remotely
    _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend remote

    # To stop it gracefully (you may also send SIGINT/SIGTERM)
    _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend stop

To list all commands:

    _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend
```
Se puede ejecutar en cualquier máquina con el mismo OS, aunque no tenga erlang.
```
$ _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend
Usage: elixir_secret_friend COMMAND [ARGS]

The known commands are:

    start          Starts the system
    start_iex      Starts the system with IEx attached
    daemon         Starts the system as a daemon
    daemon_iex     Starts the system as a daemon with IEx attached
    eval "EXPR"    Executes the given expression on a new, non-booted system
    rpc "EXPR"     Executes the given expression remotely on the running system
    remote         Connects to the running system via a remote shell
    restart        Restarts the running system via a remote command
    stop           Stops the running system via a remote command
    pid            Prints the operating system PID of the running system via a remote command
    version        Prints the release name and version to be booted

$ _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend daemon
$ _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend rpc 'IO.inspect 1 + 2'
3
$ _build/dev/rel/elixir_secret_friend/bin/elixir_secret_friend rpc 'IO.inspect SecretFriend.API.SFList.show(:supervised)'
[]
```
---
Este trozo de código,...
```
  def create_selection(sflist) do
    sflist
    |> Enum.shuffle()
    |> gen_pairs()
  end

  # Funcion privada que encapsula la parte de barajar,
  # para poder pasarlo como leftover al chunk_every
  defp gen_pairs(sflist), do: Enum.chunk_every(sflist, 2, 1, sflist)
```
...en elixir 12 se puede hacer ya pasándole una lambda usando then()
---
En nuestra app, habíamos hecho una implementación ideal para servicios singleton:
```
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
```
Para tener múltiples listas necesitamos un supervisor dinámico.
Vamos a hacer un módulo `boundary` para que nuestra API no vuelva a hablar con los workers, sino con los supervisores.
Dentro dell módulo un `SFListsSupervisor` con behavior `DynamicSupervisor`.
```
defmodule SecretFriend.Boundary.SFListsSupervisor do
  use DynamicSupervisor
  
end
```
Eso requiere un start_link y un init.
```
defmodule SecretFriend.Boundary.SFListsSupervisor do
  use DynamicSupervisor

  def start_link(_args) do
    # (module, initial_argument, options)
    DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    # one for one: las listas son independientes. Si falla una lista reinicio solo esa.
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
```
Falta decirle cómo queremos añadir nuevos "hijos".
```

  def create_sflist(name) do
    # child_spec: mapa id: worker, start: tupla con modulo, función arranque y argumentos.
    # o, si el worker define el child_spec: child_spec: tupla con el módulo y los args del start_link
    # { module, [arg1: val1, arg2: val2]} -> los corchetes se pueden quitar
    child_spec = %{id: SFWorker, start: {SecretFriend.Worker.SFWorker, :start_link, [name]}}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
```
Probamos:
```
iex(1)> alias SecretFriend.Boundary.SFListsSupervisor
SecretFriend.Boundary.SFListsSupervisor
iex(2)> SFListsSupervisor.start_link(:ignore)
{:ok, #PID<0.167.0>}
```
Vemos que devuelve un pid. Le añado procesos:
```
iex(3)> SFListsSupervisor.create_sflist(:navidad)
{:ok, #PID<0.168.0>}
iex(4)> SFListsSupervisor.create_sflist(:navidad)
{:error, {:already_started, #PID<0.168.0>}}
iex(5)> SFListsSupervisor.create_sflist(:reyes)  
{:ok, #PID<0.171.0>}
iex(6)> DynamicSupervisor.which_children(SF
SFList               SFListsSupervisor    SFWorker             

iex(6)> DynamicSupervisor.which_children(SFListsSupervisor)
[
  {:undefined, #PID<0.168.0>, :worker, [SecretFriend.Worker.SFWorker]},
  {:undefined, #PID<0.171.0>, :worker, [SecretFriend.Worker.SFWorker]}
]
```
Vemos que no puedo poner dos veces el mismo nombre.
Si pruebo a matar una lista se reinicia.
Pierde el estado, pero volvemos a tener la lista.
Vamos a ver un ejemplo de cómo podríamos guardar el estado en una tabla, para recuperarlo cuando resucite un proceos muerto.
En el ejemplo, no realista, haremos que cuando se cree una selección se guarde el estado, pero cuando añadamos una amigo no, de forma que el estado del servidor y el guardado no sean el mismo.
En ese caso, si se muere un proceso puedo recuperar el último estado guardado. No sería el mismo que había al morir, pero es un estado coherente.
Eso simula por ejemplo si el sistema pierde la capacidad de añadir nuevas personas, porque ppor ejemplo revienta, pero yo puedo seguir trabajando con la selección creada.

---
Primero vamos a cambiar nuestro API para que no hable con el worker sino con el bundary.
Cambio
```
defmodule SecretFriend.API.SFList do
  alias SecretFriend.Worker.SFWorker

  def new(name) do
    SFWorker.start_link(name)
    name
  end
  ...
end
```
por:
```
defmodule SecretFriend.API.SFList do
  alias SecretFriend.Boundary.SFListsSupervisor

  def new(name) do
    SFListsSupervisor.create_sflist(name)
    name
  end
  ...
end
```
Y en la App:
```
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
```
por
```
 defmodule SecretFriend do
  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      {SecretFriend.Boundary.SFListsSupervisor, :noargs}
    ]
    opts = [strategy: :one_for_one, name: SecretFriend.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```
Hay un supervisor "estático" (el que defines sus hijos en tiempo de compilación) que es "singleton", que es el supervisor dinámico, al cual ya se pueden añadir hijos en tiempo de ejecución.
Vemos que ha funcionado:
```
iex(1)> DynamicSupervisor.which_children(SecretFriend.Supervisor)
[
  {SecretFriend.Boundary.SFListsSupervisor, #PID<0.173.0>, :supervisor,
   [SecretFriend.Boundary.SFListsSupervisor]} 
]
iex(2)> DynamicSupervisor.which_children(SecretFriend.Boundary.SFListsSupervisor)
[{:undefined, #PID<0.175.0>, :worker, [SecretFriend.Worker.SFWorker]}]
iex(3)> [{_, pid, _, _}] = v
[{:undefined, #PID<0.175.0>, :worker, [SecretFriend.Worker.SFWorker]}]
iex(4)> Process.info(pid)
[
  registered_name: :lista1,
  current_function: {:gen_server, :loop, 7},
  initial_call: {:proc_lib, :init_p, 5},
  status: :waiting,
  message_queue_len: 0,
  links: [#PID<0.173.0>],
  dictionary: [
    "$ancestors": [SecretFriend.Boundary.SFListsSupervisor,
     SecretFriend.Supervisor, #PID<0.171.0>],
    "$initial_call": {SecretFriend.Worker.SFWorker, :init, 1}
  ],
  trap_exit: false,
  error_handler: :error_handler,
  priority: :normal,
  group_leader: #PID<0.170.0>,
  total_heap_size: 233,
  heap_size: 233,
  stack_size: 12,
  reductions: 104,
  garbage_collection: [
    max_heap_size: %{error_logger: true, kill: true, size: 0},
    min_bin_vheap_size: 46422,
    min_heap_size: 233,
    fullsweep_after: 65535,
    minor_gcs: 0
  ],
  suspending: []
]
```
