defmodule ReactiveEntity do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(type, []) do
    start(type,[%{}])
  end
  def start(_type, [config]) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(ReactiveEntity.Worker, [arg1, arg2, arg3])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ReactiveEntity.Supervisor]
    sup=Supervisor.start_link(children, opts)

    Reactive.Entities.init(config)
    sup
  end
end
