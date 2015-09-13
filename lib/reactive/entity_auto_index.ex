defmodule Reactive.EntityAutoIndex do
  require Logger

  def add_to_index(index,key,id) when is_binary(key) do
    db=Reactive.Entities.get_db()
    Reactive.EntitiesIndexDb.add({db,index},key,id)
  end
  def add_to_index(index,key,id) when is_list(key) do
    db=Reactive.Entities.get_db()
    Enum.each(key,fn(k) -> Reactive.EntitiesIndexDb.add({db,index},k,id) end)
  end
  def remove_from_index(index,key,id) when is_binary(key) do
    db=Reactive.Entities.get_db()
    Reactive.EntitiesIndexDb.delete({db,index},key,id)
  end
  def remove_from_index(index,key,id) when is_list(key) do
    db=Reactive.Entities.get_db()
    Enum.each(key,fn(k) -> Reactive.EntitiesIndexDb.delete({db,index},k,id) end)
  end
  def update_index(index,keys1,keys2,id) when is_binary(keys1) and is_binary(keys2) do
    remove_from_index(index,keys1,id)
    add_to_index(index,keys2,id)
  end
  def update_index(index,keys1,keys2,id) do
    s1 = if is_list(keys1) do
      HashSet.new(keys1)
    else
      HashSet.new([keys1])
    end
    s2 = if is_list(keys2) do
      HashSet.new(keys2)
    else
      HashSet.new([keys2])
    end
    remove_from_index(index,Set.to_list(Set.difference(s1,s2)),id)
    add_to_index(index,Set.to_list(Set.difference(s2,s1)),id)
  end

  def prepare_container(container,indexed_values) do
    Map.put(container,:indexed_values, indexed_values)
  end
  def index_when_saving(id,container,values) do
    Logger.debug("INDEX WHEN SAVING #{inspect container} #{inspect values}")
    cindexed_values=Map.get(container,:indexed_values,%{})
    new_values=Map.to_list(Map.drop(values,Map.keys(cindexed_values)))
    Logger.debug("INDEX NEW VALUES #{inspect new_values}")
    mmodified_values=Enum.map(Map.to_list(cindexed_values),
      fn({k,v}) ->
        {k,v,Map.get(values,k,:dropped)}
      end)
    modified_values=Enum.filter(mmodified_values,fn({_k,v1,v2}) -> v1 != v2 end)
    Enum.each(new_values, fn({k,v}) -> add_to_index(k,v,id) end)
    Logger.debug("INDEX MODIFIED #{inspect modified_values}")
    Enum.each(modified_values, fn
        ({k,v,:dropped}) -> remove_from_index(k,v,id)
        ({k,v1,v2}) ->
          update_index(k,v1,v2,id)
      end)
    clean_container=Map.delete(container,:indexed_values)
    ncontainer=Map.put(container,:indexed_values,values)
    {ncontainer,clean_container}
  end
  def index_not_indexed_entity(id,container,indexed_values) do
    l=Map.to_list(indexed_values)
    Enum.each(l,fn({k,v}) -> add_to_index(k,v,id) end)
    ncontainer=Map.put(container,:indexed_values,indexed_values)
    ncontainer
  end

  def save_auto_index(id,state,container,indexed_values) do
    {ncontainer,clean_container}=index_when_saving(id,container,indexed_values.(state))
    Reactive.Entities.save_entity(id,state,clean_container)
    {:update_container,ncontainer}
  end
  def retrive_auto_index(id,indexed_values) do
    case Reactive.Entities.retrive_entity(id) do
      :not_found -> :not_found
      {:ok,%{state: state, container: container}} ->
        {:ok,%{state: state, container: prepare_container(container,indexed_values.(state)) }}
    end
  end

  def __using__(_opts) do
    quote location: :keep do
      def save(id,state,container) do
        Reactive.EntityAutoIndex.save_auto_index(id,state,container,&indexed_values/1)
      end
      def retrive(id) do
        Reactive.EntityAutoIndex.retrive_auto_index(id,&indexed_values/1)
      end
    end
  end
end