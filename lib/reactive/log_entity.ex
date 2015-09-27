defmodule Reactive.LogEntity do

  defmacro __using__(_opts) do
    quote location: :keep do
      use Reactive.Entity

      def retrive(id) do
        case Reactive.Entities.retrive_entity(id) do
          :not_found -> :not_found
          {:ok,%{state: state, container: container}} ->
             logId = Reactive.EntitiesDb.entity_db_id(id) <> ".log"
             nstate=Map.put(state,:log,Reactive.LogsDb.create(Reactive.Entities.get_db(),logId))
             {:ok,%{state: nstate, container: container}}
        end
      end

      def init_log(state,id) do
        logDb = Reactive.Entities.get_db()
        logId = Reactive.EntitiesDb.entity_db_id(id) <> ".log"
        log = Reactive.LogsDb.create(logDb,logId)
        state
          |> Map.put(:log,log)
          |> Map.put(:uniq,0)
      end

      def save(id,state,container) do
        nstate=Dict.delete(state,:log)
        Reactive.Entities.save_entity(id,nstate,container)
        :ok
      end

      def add_to_log(state,timestamp,uniq,data) do
        key=Integer.to_string(timestamp)<>"|"<>uniq
        Reactive.LogsDb.put(state.log,key,data)
        key
      end

      def remove_from_log(state,timestamp,uniq) do
        Reactive.LogsDb.delete(state.log,Integer.to_string(timestamp)<>"|"<>uniq)
      end

      def scan(state,from,to,limit \\ 1_000,reverse \\ false) do
        f=case from do
            :begin -> :begin
            :end -> :end
            i -> Integer.to_string(i)
          end
        t=case to do
            :begin -> :begin
            :end -> :end
            i -> Integer.to_string(i)
          end
        sr=Reactive.LogsDb.scan(state.log,f,t,limit,reverse)
        Enum.map(sr,fn({sr,v}) ->
          [sts,suq]=String.split(sr,"|")
          {Integer.parse(sts),Integer.parse(suq),v}
        end)
      end
    end
  end
end