defmodule Reactive.NodesRange do
  require Logger

  def load_or_create(table_name) do
    case load(table_name) do
      {:ok,table} -> {:ok,table}
      {:error,error} -> create(table_name)
    end
  end

  def create(table_name) do
    :ets.new(table_name,[:ordered_set, :public, :named_table, {:read_concurrency, true}])
  end

  def load(table_name) do
    :ets.file2tab(table_name)
  end

  def save(table_name) do
    :ets.tab2file(table_name,:erlang.atom_to_list(table_name)++'.ets')
  end

  def get_node(table_name,key) do
    nk = case :ets.next(table_name,key) do
      '$end_of_table' -> :ets.last(table_name)
      k -> k
    end
    [{_,node}] = :ets.lookup(table_name,key)
    node
  end

  def get_iterator(table_name,key) do
    nk = case :ets.next(table_name,key) do
      '$end_of_table' -> :ets.last(table_name)
      k -> k
    end
    [{k,node}] = :ets.lookup(table_name,key)
    {node,table_name,k}
  end

  def next({_,table_name,key}) do
    nk = case :ets.next(table_name,key) do
      '$end_of_table' -> :end
      k ->
        [{k,node}] = :ets.lookup(table_name,key)
        {node,table_name,k}
    end
  end

  def prev({_,table_name,key}) do
    nk = case :ets.prev(table_name,key) do
      '$end_of_table' -> :end
      k ->
        [{k,node}] = :ets.lookup(table_name,key)
        {node,table_name,k}
    end
  end
end