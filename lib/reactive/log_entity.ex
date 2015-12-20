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

      def get_log_key(timestamp,uniq) do
        :erlang.iolist_to_binary([:io_lib.format("~14.10.0B",[timestamp]),"|",uniq])
        #Integer.to_string(timestamp)<>"|"<>uniq
      end

      def add_to_log(state,timestamp,uniq,data) do
        key=get_log_key(timestamp,uniq)
        Reactive.LogsDb.put(state.log,key,data)
        key
      end

      def remove_from_log(state,timestamp,uniq) do
        Reactive.LogsDb.delete(state.log,get_log_key(timestamp,uniq))
      end

      def overwrite_log(state,timestamp,uniq,data) do
        key=get_log_key(timestamp,uniq)
        Reactive.LogsDb.put(state.log,key,data)
      end

      def update_log(state,timestamp,uniq,update_fun) do
        key=get_log_key(timestamp,uniq)
        data=get(state.log,key)
        ndata=update_fun.(data)
        Reactive.LogsDb.put(state.log,key,ndata)
        ndata
      end

      def update_log(state,key,update_fun) do
        data=Reactive.LogsDb.get(state.log,key)
        ndata=update_fun.(data)
        Reactive.LogsDb.put(state.log,key,ndata)
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