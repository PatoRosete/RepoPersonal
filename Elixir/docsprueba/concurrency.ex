# Concurrency and OTP patterns in Elixir
#
# This file covers: GenServer, Supervisor, Task, Agent,
# send/receive, spawn, process monitors, and registries.

defmodule Concurrency.Counter do
  @moduledoc """
  A simple counter backed by a GenServer.
  Covers: GenServer callbacks, call, cast, state management.
  """
  use GenServer

  # ── Client API ────────────────────────────────────────────────────────────

  def start_link(initial \\ 0) do
    GenServer.start_link(__MODULE__, initial, name: __MODULE__)
  end

  def increment(amount \\ 1),  do: GenServer.cast(__MODULE__, {:increment, amount})
  def decrement(amount \\ 1),  do: GenServer.cast(__MODULE__, {:decrement, amount})
  def reset(),                  do: GenServer.cast(__MODULE__, :reset)
  def value(),                  do: GenServer.call(__MODULE__, :value)
  def stop(),                   do: GenServer.stop(__MODULE__)

  # ── Server callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(initial) when is_integer(initial) and initial >= 0 do
    {:ok, initial}
  end
  def init(_), do: {:stop, :bad_initial_value}

  @impl true
  def handle_call(:value, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:increment, amount}, state) do
    {:noreply, state + amount}
  end
  def handle_cast({:decrement, amount}, state) do
    {:noreply, max(0, state - amount)}
  end
  def handle_cast(:reset, _state) do
    {:noreply, 0}
  end

  @impl true
  def handle_info(:tick, state) do
    IO.puts("Counter tick: #{state}")
    {:noreply, state}
  end
  def handle_info(msg, state) do
    IO.warn("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(reason, state) do
    IO.puts("Counter terminating with reason=#{inspect(reason)}, final value=#{state}")
    :ok
  end

end

defmodule Concurrency.KeyValueStore do
  @moduledoc """
  An in-memory key-value store.
  Covers: GenServer with map state, ETS alternative pattern.
  """
  use GenServer

  # ── Client API ────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def put(pid, key, value),    do: GenServer.call(pid, {:put, key, value})
  def get(pid, key),           do: GenServer.call(pid, {:get, key})
  def delete(pid, key),        do: GenServer.call(pid, {:delete, key})
  def keys(pid),               do: GenServer.call(pid, :keys)
  def all(pid),                do: GenServer.call(pid, :all)
  def clear(pid),              do: GenServer.cast(pid, :clear)

  # ── Server callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(initial_map), do: {:ok, initial_map}

  @impl true
  def handle_call({:put, key, value}, _from, store) do
    {:reply, :ok, Map.put(store, key, value)}
  end
  def handle_call({:get, key}, _from, store) do
    {:reply, Map.get(store, key), store}
  end
  def handle_call({:delete, key}, _from, store) do
    {:reply, :ok, Map.delete(store, key)}
  end
  def handle_call(:keys, _from, store) do
    {:reply, Map.keys(store), store}
  end
  def handle_call(:all, _from, store) do
    {:reply, store, store}
  end

  @impl true
  def handle_cast(:clear, _store) do
    {:noreply, %{}}
  end

end

defmodule Concurrency.TaskSupervisor do
  @moduledoc """
  Demonstrates supervised tasks and parallel computation.
  Covers: Task.async, Task.await, Task.async_stream, Task.Supervisor.
  """

  # Run a list of functions in parallel and collect results
  def parallel_map(list, fun, timeout \\ 5000) do
    list
    |> Enum.map(fn item -> Task.async(fn -> fun.(item) end) end)
    |> Enum.map(fn task -> Task.await(task, timeout) end)
  end

  # Parallel map using async_stream (back-pressured, bounded concurrency)
  def bounded_parallel_map(list, fun, max_concurrency \\ System.schedulers_online()) do
    list
    |> Task.async_stream(fun,
         max_concurrency: max_concurrency,
         timeout: :infinity,
         on_timeout: :kill_task)
    |> Enum.map(fn {:ok, result} -> result end)
  end

  # Fire-and-forget tasks
  def fire_and_forget(fun) do
    Task.start(fn ->
      try do
        fun.()
      rescue
        e -> IO.warn("Background task failed: #{inspect(e)}")
      end
    end)
  end

  # Aggregate results from multiple data sources in parallel
  def fetch_all(sources) when is_list(sources) do
    sources
    |> Task.async_stream(fn {name, fetch_fn} ->
         {name, fetch_fn.()}
       end,
       max_concurrency: length(sources),
       timeout: 10_000)
    |> Enum.reduce(%{}, fn {:ok, {name, result}}, acc ->
         Map.put(acc, name, result)
       end)
  end

end

defmodule Concurrency.AgentCache do
  @moduledoc """
  A simple cache built on top of Agent.
  Covers: Agent.start_link, Agent.get, Agent.update, Agent.get_and_update.
  """

  def start_link(opts \\ []) do
    Agent.start_link(fn -> %{} end, opts)
  end

  def get(cache, key) do
    Agent.get(cache, fn state -> Map.get(state, key) end)
  end

  def put(cache, key, value) do
    Agent.update(cache, fn state -> Map.put(state, key, value) end)
  end

  # Get or compute: if the key exists return it, otherwise compute and store
  def fetch(cache, key, compute_fn) do
    Agent.get_and_update(cache, fn state ->
      case Map.get(state, key) do
        nil ->
          value     = compute_fn.()
          new_state = Map.put(state, key, value)
          {value, new_state}
        cached ->
          {cached, state}
      end
    end)
  end

  def invalidate(cache, key) do
    Agent.update(cache, fn state -> Map.delete(state, key) end)
  end

  def flush(cache) do
    Agent.update(cache, fn _state -> %{} end)
  end

  def size(cache) do
    Agent.get(cache, fn state -> map_size(state) end)
  end

end

defmodule Concurrency.PubSub do
  @moduledoc """
  A minimal publish-subscribe system.
  Covers: GenServer, send/receive, process registration, monitors.
  """
  use GenServer

  defstruct subscriptions: %{}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def subscribe(server, topic) do
    GenServer.call(server, {:subscribe, topic, self()})
  end

  def unsubscribe(server, topic) do
    GenServer.call(server, {:unsubscribe, topic, self()})
  end

  def publish(server, topic, message) do
    GenServer.cast(server, {:publish, topic, message})
  end

  # ── Server callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:subscribe, topic, pid}, _from, subs) do
    Process.monitor(pid)
    updated = Map.update(subs, topic, MapSet.new([pid]), fn set ->
      MapSet.put(set, pid)
    end)
    {:reply, :ok, updated}
  end
  def handle_call({:unsubscribe, topic, pid}, _from, subs) do
    updated = Map.update(subs, topic, MapSet.new(), fn set ->
      MapSet.delete(set, pid)
    end)
    {:reply, :ok, updated}
  end

  @impl true
  def handle_cast({:publish, topic, message}, subs) do
    Map.get(subs, topic, MapSet.new())
    |> MapSet.to_list()
    |> Enum.each(fn pid -> send(pid, {:pubsub, topic, message}) end)
    {:noreply, subs}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, subs) do
    # Clean up all subscriptions for the dead process
    updated = Map.new(subs, fn {topic, pids} ->
      {topic, MapSet.delete(pids, pid)}
    end)
    {:noreply, updated}
  end

end

defmodule Concurrency.RateLimiter do
  @moduledoc """
  A token-bucket rate limiter.
  Covers: GenServer, :timer.send_interval, state with multiple fields.
  """
  use GenServer

  @refill_interval_ms 1_000

  defstruct [:max_tokens, :tokens, :refill_amount]

  def start_link(max_tokens, refill_amount \\ nil) do
    refill = refill_amount || max_tokens
    GenServer.start_link(__MODULE__,
      %__MODULE__{max_tokens: max_tokens, tokens: max_tokens, refill_amount: refill})
  end

  def acquire(pid, cost \\ 1) do
    GenServer.call(pid, {:acquire, cost})
  end

  def remaining(pid), do: GenServer.call(pid, :remaining)

  @impl true
  def init(state) do
    :timer.send_interval(@refill_interval_ms, :refill)
    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, cost}, _from, %{tokens: t} = state) when t >= cost do
    {:reply, :ok, %{state | tokens: t - cost}}
  end
  def handle_call({:acquire, _cost}, _from, state) do
    {:reply, {:error, :rate_limited}, state}
  end
  def handle_call(:remaining, _from, %{tokens: t} = state) do
    {:reply, t, state}
  end

  @impl true
  def handle_info(:refill, %{tokens: t, max_tokens: max, refill_amount: r} = state) do
    {:noreply, %{state | tokens: min(max, t + r)}}
  end

end
