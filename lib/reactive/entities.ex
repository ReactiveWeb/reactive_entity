defmodule Reactive.Entities do
  @type entity_id() :: {term(),list(term())}

  def init(config) do
    :ets.new(__MODULE__, [:named_table, :public, :set, {:keypos, 1}])
    {:ok,store}=:eleveldb.open(Map.get(config,:store_filename,"entities") |> to_char_list, [create_if_missing: true])
    :ets.insert(__MODULE__,{:store,store})
  end

  @spec get_entity(Id::entity_id()) :: pid()
  def get_entity(id = [module | args]) do
    :io.format("get_entity called with ~p ~n",[id])
    lr=:ets.lookup(__MODULE__,Id)
    :io.format("entity lookup ~p = ~p ~n",[id,lr])

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

  defp entity_db_id(_id=[module | args]) do
    IO.inspect(args)
    argss =  Enum.map( args , fn ( x ) ->  [ :erlang.term_to_binary( x ), ","] end )
    :erlang.iolist_to_binary( ["e:",:erlang.atom_to_list(module),":",argss ] )
  end

  def save_entity(id,state,container) do
    [{:store,store}]=:ets.lookup(__MODULE__,:store)
    data=:erlang.term_to_binary(%{ :state => state, :container => container })
    :eleveldb.put(store,entity_db_id(id),data,[]);
  end

  def retrive_entity(id) do
    [{:store,store}]=:ets.lookup(__MODULE__,:store)
    case :eleveldb.get(store,entity_db_id(id),[]) do
      {:ok, binary} -> {:ok,:erlang.binary_to_term(binary)}
      not_found -> not_found
    end
  end



end