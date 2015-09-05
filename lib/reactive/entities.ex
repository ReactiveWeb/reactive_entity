defmodule Reactive.Entities do
  @type entity_id() :: {term(),list(term())}

  def init(config) do
    :ets.new(__MODULE__, [:named_table, :public, :set, {:keypos, 1}])
    #{:ok,store}=:eleveldb.open(Map.get(config,:store_filename,"entities") |> to_char_list, [create_if_missing: true])
    store=Reactive.LocalDb.open(Path.expand(Map.get(config,:store_filename,"entities")))
    :ets.insert(__MODULE__,{:store,store})
  end

  @spec get_entity(id::entity_id()) :: pid()
  def get_entity(id = [module | args]) do
    lr=:ets.lookup(__MODULE__,id)

    case lr do
      [{^id,:existing,pid}] -> pid
      [{^id,:starting}] -> receive do
                          after
                            23 -> get_entity(id)
                          end
      [] ->
        :ets.insert(__MODULE__,{id,:starting})
        pid=Reactive.Entity.start(module,args)
        :ets.insert(__MODULE__,{id,:existing,pid})
        pid
    end
  end

  def create_entity(id = [module | args],state,container) do
   ## :io.format("get_entity called with ~p ~n",[id])
    lr=:ets.lookup(__MODULE__,id)
   ## :io.format("entity lookup ~p = ~p ~n",[id,lr])

    case lr do
      [{^id,:existing,pid}] -> pid
      [{^id,:starting}] -> receive do
                          after
                            23 -> create_entity(id,state,container)
                          end
      [] ->
        :ets.insert(__MODULE__,{id,:starting})
        pid=Reactive.Entity.start(module,args,state,container)
        :ets.insert(__MODULE__,{id,:existing,pid})
        pid
    end
  end

  def is_entity_running(id = [_module | _args]) do
    lr=:ets.lookup(__MODULE__,id)
    case lr do
      [{_id,:existing,_pid}] -> true
      [{_id,:starting}] -> true
      [] -> false
    end
  end

  def report_frozen(id) do
    :ets.delete(__MODULE__,id)
  end


  def save_entity(id,state,container) do
    cleanObservers=:maps.map(fn(k,v) -> Enum.filter(v,
             fn
               (p) when is_pid(p) -> false
               _ -> true
             end ) end, container.observers)
    cleanContainer=%{container | observers: cleanObservers, observers_monitors: %{} }
    store(id,%{ :state => state, :container => cleanContainer })
  end

  def retrive_entity(id) do
    retrive(id)
  end

  def get_db() do
    [{:store,store}]=:ets.lookup(__MODULE__,:store)
    store
  end

  defp store(id=[m|a],data) do
    case :ets.lookup(__MODULE__,{:store,m}) do
      [{{:store,^m},{read,write}}] -> write.(id,data)
      [] ->
        store=get_db()
        #sdata=:erlang.term_to_binary(data)
        #:eleveldb.put(store,entity_db_id(id),sdata,[]);
        Reactive.EntitiesDb.store(store,id,data)
    end
  end

  defp retrive(id=[m|a]) do
    case :ets.lookup(__MODULE__,{:store,m}) do
      [{{:store,^m},{read,write}}] -> read.(id)
      _ ->
        store=get_db()
        #case :eleveldb.get(store,entity_db_id(id),[]) do
        #  {:ok, binary} -> {:ok,:erlang.binary_to_term(binary)}
        #  not_found -> not_found
        #end

        Reactive.EntitiesDb.retrive(store,id)
    end
  end

end