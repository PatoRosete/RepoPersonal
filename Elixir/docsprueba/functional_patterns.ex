# Error handling, streams, File I/O, and functional patterns
#
# This file covers: try/rescue/catch, throw, with, Stream,
# File operations, Enum pipelines, captures, and anonymous functions.

defmodule ErrorHandling.Examples do
  @moduledoc """
  Demonstrates different error handling strategies in Elixir.
  """

  # try / rescue
  def safe_divide(_, 0) do
    {:error, :division_by_zero}
  end
  def safe_divide(a, b) do
    {:ok, a / b}
  end

  def risky_divide(a, b) do
    try do
      result = a / b
      {:ok, result}
    rescue
      ArithmeticError -> {:error, :arithmetic_error}
    end
  end

  # try / catch for throws
  def compute_with_timeout(fun, timeout_ms) do
    task = Task.async(fun)
    try do
      {:ok, Task.await(task, timeout_ms)}
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
    end
  end

  # Wrapping external calls
  def safe_parse_int(str) do
    try do
      {:ok, String.to_integer(str)}
    rescue
      ArgumentError -> {:error, :not_an_integer}
    end
  end

  def safe_parse_float(str) do
    try do
      {:ok, String.to_float(str)}
    rescue
      ArgumentError ->
        # Maybe it's a plain integer written as a float
        case safe_parse_int(str) do
          {:ok, n}    -> {:ok, n * 1.0}
          {:error, _} -> {:error, :not_a_number}
        end
    end
  end

  # Chaining fallible operations with with
  def process_config(raw) do
    with {:ok, decoded} <- Jason.decode(raw),
         {:ok, host}    <- Map.fetch(decoded, "host"),
         {:ok, port}    <- Map.fetch(decoded, "port"),
         true           <- is_integer(port) || {:error, :port_not_integer},
         true           <- port in 1..65535  || {:error, :port_out_of_range} do
      {:ok, %{host: host, port: port}}
    end
  end

end

defmodule Functional.Combinators do
  @moduledoc """
  Higher-order functions and functional combinators.
  Covers: anonymous functions, captures, closures, function composition.
  """

  # Function composition
  def compose(f, g) do
    fn x -> f.(g.(x)) end
  end

  def pipe(fns) do
    fn x -> Enum.reduce(fns, x, fn f, acc -> f.(acc) end) end
  end

  # Memoization using a closure over an Agent
  def memoize(fun) do
    {:ok, cache} = Agent.start_link(fn -> %{} end)
    fn args ->
      case Agent.get(cache, fn state -> Map.get(state, args) end) do
        nil ->
          result = apply(fun, List.wrap(args))
          Agent.update(cache, fn state -> Map.put(state, args, result) end)
          result
        cached ->
          cached
      end
    end
  end

  # Partial application
  def partial(f, first_arg) do
    fn rest -> apply(f, [first_arg | List.wrap(rest)]) end
  end

  # Retry a function up to n times
  def retry(fun, max_attempts, delay_ms \\ 0) do
    do_retry(fun, max_attempts, delay_ms, 1)
  end

  defp do_retry(fun, max, _delay, attempt) when attempt > max do
    {:error, {:max_retries_exceeded, max}}
  end
  defp do_retry(fun, max, delay, attempt) do
    case fun.() do
      {:ok, _} = success ->
        success
      {:error, _} ->
        if delay > 0, do: Process.sleep(delay)
        do_retry(fun, max, delay, attempt + 1)
      other ->
        other
    end
  end

  # Tap: apply a side-effect function and return the original value
  def tap(value, fun) do
    fun.(value)
    value
  end

  # Then: apply a function only if value is truthy
  def then_if(nil,   _fun), do: nil
  def then_if(false, _fun), do: false
  def then_if(value,  fun), do: fun.(value)

end

defmodule Functional.Collections do
  @moduledoc """
  Advanced collection operations.
  Covers: Enum, Stream, zip, flat_map, group_by, reduce, scan.
  """

  # Deep map over nested structures
  def deep_map(value, fun) when is_list(value) do
    Enum.map(value, &deep_map(&1, fun))
  end
  def deep_map(value, fun) when is_map(value) do
    Map.new(value, fn {k, v} -> {k, deep_map(v, fun)} end)
  end
  def deep_map(value, fun), do: fun.(value)

  # Flatten a nested map into dot-separated keys
  def flatten_map(map, prefix \\ "") do
    Enum.flat_map(map, fn {key, value} ->
      full_key = if prefix == "", do: "#{key}", else: "#{prefix}.#{key}"
      case value do
        %{} = nested -> flatten_map(nested, full_key)
        _            -> [{full_key, value}]
      end
    end)
    |> Map.new()
  end

  # Group and count
  def frequency_map(list) do
    Enum.frequencies(list)
  end

  def top_n(list, n, key_fn \\ &(&1)) do
    list
    |> Enum.sort_by(key_fn, :desc)
    |> Enum.take(n)
  end

  # Partition into chunks that satisfy a predicate
  def partition_by_size(list, chunk_size) do
    Enum.chunk_every(list, chunk_size)
  end

  # Running totals
  def cumulative_sum(numbers) do
    numbers
    |> Stream.scan(0, &(&1 + &2))
    |> Enum.to_list()
  end

  # Interleave two lists
  def interleave([], ys),       do: ys
  def interleave(xs, []),       do: xs
  def interleave([x | xs], [y | ys]), do: [x, y | interleave(xs, ys)]

  # Zip three lists together
  def zip3([], _, _),           do: []
  def zip3(_, [], _),           do: []
  def zip3(_, _, []),           do: []
  def zip3([a|as], [b|bs], [c|cs]) do
    [{a, b, c} | zip3(as, bs, cs)]
  end

  # unfold: generate a list from a seed
  def unfold(seed, fun) do
    Stream.unfold(seed, fun) |> Enum.to_list()
  end

  # Example: generate fibonacci numbers lazily
  def fibonacci_stream() do
    Stream.unfold({0, 1}, fn {a, b} -> {a, {b, a + b}} end)
  end

  def first_n_fibs(n) do
    fibonacci_stream() |> Enum.take(n)
  end

end

defmodule FileIO.TextProcessor do
  @moduledoc """
  File reading and text processing using streams.
  Covers: File.stream!, Stream, Enum, string operations.
  """

  # Count lines, words, and characters in a file
  def wc(path) do
    path
    |> File.stream!()
    |> Enum.reduce({0, 0, 0}, fn line, {lines, words, chars} ->
         word_count = line |> String.split() |> length()
         {lines + 1, words + word_count, chars + String.length(line)}
       end)
    |> then(fn {l, w, c} -> %{lines: l, words: w, chars: c} end)
  end

  # Find lines matching a regex
  def grep(path, pattern) do
    regex = if is_binary(pattern), do: Regex.compile!(pattern), else: pattern
    path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.filter(fn {line, _n} -> Regex.match?(regex, line) end)
    |> Enum.map(fn {line, n} -> {n, String.trim_trailing(line)} end)
  end

  # Read a CSV file into a list of maps
  def read_csv(path) do
    [header_line | data_lines] = File.stream!(path) |> Enum.to_list()
    headers = header_line |> String.trim() |> String.split(",") |> Enum.map(&String.to_atom/1)
    Enum.map(data_lines, fn line ->
      values = line |> String.trim() |> String.split(",")
      Enum.zip(headers, values) |> Map.new()
    end)
  end

  # Write a list of maps to a CSV file
  def write_csv(path, [first | _] = records) do
    headers = Map.keys(first)
    header_line = headers |> Enum.map(&to_string/1) |> Enum.join(",")
    data_lines  = Enum.map(records, fn row ->
      headers
      |> Enum.map(fn h -> to_string(Map.get(row, h, "")) end)
      |> Enum.join(",")
    end)
    File.write!(path, Enum.join([header_line | data_lines], "\n"))
  end

  # Tail a file (last n lines)
  def tail(path, n) do
    path
    |> File.stream!()
    |> Enum.to_list()
    |> Enum.take(-n)
  end

  # Head of a file (first n lines)
  def head(path, n) do
    path
    |> File.stream!()
    |> Enum.take(n)
  end

end

defmodule Functional.MaybeMonad do
  @moduledoc """
  A simple Maybe monad implementation.
  Covers: tagged tuples, with, anonymous functions, captures.
  """

  # Wrap a value in a Maybe
  def just(value), do: {:just, value}
  def nothing(),   do: :nothing

  # Functor map
  def fmap(:nothing, _fun),        do: :nothing
  def fmap({:just, value}, fun),   do: {:just, fun.(value)}

  # Monad bind (flat_map)
  def bind(:nothing, _fun),        do: :nothing
  def bind({:just, value}, fun),   do: fun.(value)

  # Apply defaults
  def from_maybe(:nothing, default),      do: default
  def from_maybe({:just, value}, _default), do: value

  # Lift a regular function to work on Maybes
  def lift(fun) do
    fn
      :nothing       -> :nothing
      {:just, value} -> {:just, fun.(value)}
    end
  end

  # Sequence: turn a list of Maybes into a Maybe of a list
  def sequence([]), do: just([])
  def sequence([:nothing | _]), do: nothing()
  def sequence([{:just, v} | rest]) do
    case sequence(rest) do
      :nothing       -> nothing()
      {:just, vs}    -> just([v | vs])
    end
  end

end
