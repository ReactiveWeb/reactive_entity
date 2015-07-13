defmodule Reactive.Entity do
  use Behaviour

  @type entity_id() :: {term(),list(term())}
  @type entity_ref() :: entity_id() | pid()

  @doc "called when observer added"
  defcallback observe(what :: term(), state :: term, from :: entity_ref()) :: term

  @doc "called when observer removed"
  defcallback unobserve(what :: term(), state :: term, from :: entity_ref()) :: term

  @doc "check if module can freeze to DB"
  defcallback can_freeze(state :: term, observed :: map) :: boolean

  @doc "inits started module"
  defcallback init(args :: list(term())) :: {:ok, state::term()} | {:error, error::term()}

  @doc "converts module state to new version"
  defcallback convert(old_vsn :: term(), state :: term()) :: state::term()

  @doc "retrives module from db"
  defcallback retrive(id::entity_id()) :: state::term()

  @doc "saves module from db"
  defcallback save(id::entity_id(),state::term()) :: :ok

  @doc "reacts to request"
  defcallback request(req::term(), state::term(), from::pid(), rid::reference()) ::
    {:reply, reply :: term(), newState :: term()} |
    {:noreply, newState::term()}

  @doc "reacts to event"
  defcallback event(event :: term(), state::term(), from:: pid()) :: term()

  @doc "reacts to notification"
  defcallback notify(from :: term(), what :: term(), state::term()) :: term()

  @doc "reacts to other messages"
  defcallback info(message :: term(),state::term()) :: term()

  @spec sendToEntity(entity::entity_ref(), msg::term) :: :ok
  def sendToEntity(entity,msg) when is_pid(entity) do
    send entity, msg
    :ok
  end

  def sendToEntity(entity,msg) do
    sendToEntity Reactive.Entities.get_entity(entity), msg
  end

  @spec observe(entity::entity_ref(), what::term(), by::entity_ref()) :: entity_ref()
  def observe(entity,what,by \\ self()) do
    sendToEntity entity, {:observe,what,by}
    entity
  end

  @spec unobserve(entity::entity_ref(), what::term(), by::entity_ref()) :: entity_ref()
  def unobserve(entity,what,by \\ self()) do
    sendToEntity entity, {:unobserve,what,by}
    entity
  end

  @spec request(entity::entity_ref(), req::term()) :: term()
  def request(entity,req) do
    id=:erlang.make_ref()
    sendToEntity entity, {:request,id,req,self()}
    receive do
      response -> response
    end
  end

  @spec request(entity::entity_ref(), req::term(), timeout::number()) :: term()
  def request(entity,req,timeout) do
    id=:erlang.make_ref()
    sendToEntity entity, {:request,id,req,self()}
    receive do
      {:response,_id,response} -> response
    after
      timeout -> :timeout
    end
  end

  @spec event(entity::entity_ref(), event::term()) :: :ok
  def event(entity,event) do
    sendToEntity entity, {:event,event,self()}
  end

  @spec save(entity::entity_ref()) :: :ok
  def save(entity) do
    sendToEntity entity, {:save}
  end



  defmacro __using__(_opts) do
    quote location: :keep do
      @behaviour Reactive.Entity

      def observe(_what,state,_from) do
        state
      end
      def unobserve(_what,state,_from) do
        state
      end
      def can_freeze(_state,_observed) do
        true
      end
      def request(_req,state,from,rid) do
        throw "not implemented"
      end
      def event(event,state,from) do
        throw "not implemented"
      end
      def convert(_oldvsn,state) do
        state
      end
      def retrive(id) do
        Reactive.Entities.retrive_entity(id)
      end
      def save(id,state,container) do
        Reactive.Entities.save_entity(id,state,container)
      end
      def notify(from, what , state) do
        throw "not implemented"
      end
      def info(what , state) do
        throw "not implemented"
      end

      defoverridable [observe: 3,unobserve: 3,can_freeze: 2,request: 3,event: 2, convert: 2, retrive: 1, save: 3]

      @spec observe(entity::entity_ref(), what::term()) :: entity_ref()
        def observe(entity,what) do
          send self(), {:observe_entity,entity,what}
          entity
        end

      @spec unobserve(entity::entity_ref(), what::term()) :: entity_ref()
      def unobserve(entity,what) do
        send self(), {:unobserve_entity,entity,what}
        entity
      end

      @spec save_me() :: :ok
      def save_me() do
        save(self())
      end

      @spec notify_observers(signal::atom(), data::term()) :: :ok
      def notify_observers(signal,data) do
        send self(), {:notify_observers,signal,data}
      end

      @spec notify_one_observer(observer::entity_ref(), signal::atom(), data::term()) :: :ok
      def notify_one_observer(one,signal,data) do
        send self(), {:notify_one_observer,one,signal,data}
      end

      def reply(to,rid,data) do
        sendToEntity to, {:response,rid,reply}
      end
    end
  end


  ## GEARS:

  defmodule Container do
    defstruct lazy_time: 30_000, observers: %{}, observers_monitors: %{}
  end

  def start(module,args) do
    spawn(__MODULE__,:start_loop,[module,args])
  end

  def start_loop(module,args) do
    id={module,args}
    case apply(module,:retrive,[id]) do
      {:found,state,container} ->
        :io.format("persistent_entity ~p retriven from DB ~n",[id])
        :io.format("persistent_entity ~p started with pid ~p ~n",[id,self()])

        :erlang.process_flag(:trap_exit, :true)
        loop(module,id,state,container)
      :not_found ->
        :io.format("persistent_entity ~p starting with call ~p : init ( ~p ) ~n",[id,module,args])
        {:ok,state,_config} = apply(module,:init,[args])
        ## TODO: initialize container with config
        container=%Container{}
        :io.format("persistent_entity ~p started with pid ~p ~n",[id,self()])
        :erlang.process_flag(:trap_exit, :true)
        loop(module,id,state,container)
    end
  end

  defp loop(module,id,state,container) do
    receive do
      {:event,event,from} ->
        newState = apply(module,event,[event,state,from])
        loop(module,id,newState,container)

      {:request,rid,event,from} ->
        case apply(module,:request,[event,state,from,rid]) do
          {:reply,reply,newState} ->
            sendToEntity from, {:response,rid,reply}
            loop(module,id,newState,container)
          {:noreply,newState} ->
            loop(module,id,newState,container)
        end
      {:notify,from,what,data} ->
        newState=apply(module,:notify,[from,what,data])
        loop(module,id,newState,container)
      {:save} -> apply(module,:save,[id,state,container])
                 loop(module,id,state,container)
      {'DOWN',_monitor,:process,pid,_} ->
            observables=:maps.fold(fn(signal,whos,acc) ->
              if :lists.member(pid,whos) do
                :sets.add_element(signal,acc)
              else
                acc
              end
            end,:sets.new(),container.observers)
            {nstate,ncontainer}=handle_unobserve(observables,pid,module,id,state,container)
            loop(module,id,nstate,ncontainer)

      {:notify_observers,what,data} ->
        signalObservers=Maps.get(what,container.observers,[])
        :list.foreach(fn(observer) -> sendToEntity observer, {:notify,id,what,data} end, signalObservers)
        loop(module,id,state,container)
      {:notify_one_observer,observer,what,data} ->
        sendToEntity observer, {:notify,id,what,data}
        loop(module,id,state,container)
      {:observe_entity,entity,what} ->
        sendToEntity entity, {:observe,what,id}
        loop(module,id,state,container)
      {:unobserve_entity,entity,what} ->
        sendToEntity entity, {:observe,what,id}
        loop(module,id,state,container)
      {:observe,what,pid} ->
        {nstate,ncontainer}=handle_observe(what,pid,module,id,state,container)
        loop(module,id,nstate,ncontainer)
      {:unobserve,what,pid} ->
        {nstate,ncontainer}=handle_unobserve(what,pid,module,id,state,container)
        loop(module,id,nstate,ncontainer)

      msg ->
        newState=apply(module,:info,[msg,state])
        loop(module,id,newState,container)

    after
      container.lazy_time -> ## IF NO OBSERVERS THEN FREEZE
        :io.format("entity try freezing ~p Container= ~p ~n",[Id,Container])
        pid_observers_count = Maps.foldl(container.observers,0,fn (c,observers) ->
          c + Enum.count(observers,fn
              p when is_pid(p) -> true
              _p -> false
            end)
        end)
        case pid_observers_count do
          0 ->
            case apply(module,:can_freeze,[state,container.observers]) do
              true ->
                :io.format("entity freezing ~p Container= ~p ~n",[Id,Container])
                apply(module,:save,[id,state,container])
                :entities.report_frozen(Id)
              false -> loop(module,id,state,container)
            end
          _ -> loop(module,id,state,container)
        end
    end
  end

  defp handle_observe(what,pid,module,id,state,container) do
    if :sets.is_set(what) do
      :sets.to_list(what) |> List.foldl({state,container},fn(s,c) -> handle_observe(what,pid,module,id,s,c) end )
    else
      handle_observe_impl(what,pid,module,id,state,container)
    end
  end
  defp handle_observe_impl(what,pid,module,_id,state,container) do
    nmonitors = case pid do
      p when is_pid(p) -> case :maps.find(pid,container.observers_monitors) do
                                 {:ok,_Monitor} -> container.observers_monitors; ## jeśli jest to nie ma sensu dodawać i remonitorować
                                 :error -> :maps.put(pid,:erlang.monitor(:process,From),container.observers_monitors)
                               end
      _p -> container.observers_monitors
    end
    nobservers=Map.update(container.observers,what,fn (x) -> [pid | x] end)
    nstate=apply(module,:observe,[what,state,pid])
    {nstate,%{ container |
       observers: nobservers,
       observers_monitors: nmonitors
     }}
  end

  defp handle_unobserve(what,pid,module,id,state,container) do
    if :sets.is_set(what) do
      :sets.to_list(what) |> List.foldl({state,container},fn(s,c) -> handle_unobserve_impl(what,pid,module,id,s,c) end )
    else
      handle_unobserve_impl(what,pid,module,id,state,container)
    end
  end
  defp handle_unobserve_impl(what,pid,module,_id,state,container) do
    nstate=apply(module,:unobserve,[what,state,pid])
    observers=container.observers
    currentObservers=Map.get(observers,what,[])
    newObservers=List.filter(currentObservers,fn(observer) -> observer !== pid end)
    nobservers = case NewObservers do
                [] -> Map.remove(observers)
                _ -> Map.put(observers,what,newObservers)
              end

    ncontainer = case pid do
      p when is_pid(p) ->
        needMonitor=:maps.fold( ## Determines  demonitor!
            fn(_signal,observers,acc) ->
              any=:lists.any(fn(observer) -> observer==pid end,observers)
          #    io:format("DEMONITOR ?! ~p ~p ~p ~n",[From,Observers,Any]),
              acc or any
            end,false,nobservers)
               # io:format("DEMONITOR ~p ~n",[NeedMonitor]),
            case needMonitor do
              false -> %{ container |
                observers: nobservers ## no demonitor
              }
              true -> ## demonitor haha
             #   io:format("DEMONITOR!!!"),
                monitor=Map.get(container.observers_monitors,pid)
                :erlang.demonitor(monitor)
                %{  container |
                  observers: nobservers,
                  observers_monitors: :maps.remove(pid,container.observers_monitors) # remove monitor
                }
            end
      _p -> %{ container |
             observers: nobservers # no demonitor
           }
    end

    {nstate,ncontainer}
  end

end