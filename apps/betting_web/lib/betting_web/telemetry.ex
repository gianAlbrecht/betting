defmodule BettingWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {:telemetry_poller,
       measurements: periodic_measurements(),
       period: 10_000,
       name: :betting_web_poller}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      summary("phoenix.endpoint.start.system_time", unit: {:native, :millisecond}),
      summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.start.system_time", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.exception.duration", unit: {:native, :millisecond}),
      summary("phoenix.router_dispatch.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.socket_connected.duration", unit: {:native, :millisecond}),

      summary("phoenix.live_view.mount.start.system_time", unit: {:native, :millisecond}),
      summary("phoenix.live_view.mount.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.live_view.handle_event.stop.duration", unit: {:native, :millisecond}),
      summary("phoenix.live_view.handle_info.stop.duration", unit: {:native, :millisecond}),

      summary("betting_engine.repo.query.total_time", unit: {:native, :millisecond}, description: "The sum of the other measurements"),
      summary("betting_engine.repo.query.decode_time", unit: {:native, :millisecond}, description: "The time spent decoding the data received from the database"),
      summary("betting_engine.repo.query.query_time", unit: {:native, :millisecond}, description: "The time spent executing the query"),
      summary("betting_engine.repo.query.queue_time", unit: {:native, :millisecond}, description: "The time spent waiting for a database connection"),
      summary("betting_engine.repo.query.idle_time", unit: {:native, :millisecond}, description: "The time the connection spent waiting before being checked out for the query"),

      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    []
  end
end
