# Protocols, behaviours, and metaprogramming in Elixir
#
# This file covers: defprotocol, defimpl, @behaviour, @callback,
# use, __using__, macros, quote, unquote, Module attributes.

# ── Protocols ─────────────────────────────────────────────────────────────

defprotocol Printable do
  @doc "Convert any value to a human-readable string."
  def to_string(value)
end

defprotocol Serializable do
  @doc "Serialize a value to a keyword list."
  def serialize(value)

  @doc "Return the schema version this type uses."
  def version(value)
end

defprotocol Measurable do
  @doc "Return the 'size' of a data structure."
  def size(data)

  @doc "Return true if the structure has no elements."
  def empty?(data)
end

# ── Structs that implement the protocols ─────────────────────────────────

defmodule Types.Point do
  @moduledoc "A 2D point."

  defstruct [:x, :y]

  @type t :: %__MODULE__{x: number(), y: number()}

  def new(x, y), do: %__MODULE__{x: x, y: y}

  def distance(%__MODULE__{x: x1, y: y1}, %__MODULE__{x: x2, y: y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end

  def midpoint(%__MODULE__{x: x1, y: y1}, %__MODULE__{x: x2, y: y2}) do
    %__MODULE__{x: (x1 + x2) / 2, y: (y1 + y2) / 2}
  end

  defimpl Printable do
    def to_string(%Types.Point{x: x, y: y}), do: "(#{x}, #{y})"
  end

  defimpl Serializable do
    def serialize(%Types.Point{x: x, y: y}), do: [x: x, y: y]
    def version(_), do: "1.0"
  end

end

defmodule Types.Rectangle do
  @moduledoc "An axis-aligned rectangle."

  defstruct [:x, :y, :width, :height]

  def new(x, y, w, h), do: %__MODULE__{x: x, y: y, width: w, height: h}

  def area(%__MODULE__{width: w, height: h}),      do: w * h
  def perimeter(%__MODULE__{width: w, height: h}), do: 2 * (w + h)

  def contains?(%__MODULE__{x: rx, y: ry, width: w, height: h},
                %Types.Point{x: px, y: py}) do
    px >= rx and px <= rx + w and py >= ry and py <= ry + h
  end

  defimpl Printable do
    def to_string(%Types.Rectangle{x: x, y: y, width: w, height: h}) do
      "Rect(#{x}, #{y}, #{w}x#{h})"
    end
  end

  defimpl Serializable do
    def serialize(%Types.Rectangle{x: x, y: y, width: w, height: h}) do
      [x: x, y: y, width: w, height: h]
    end
    def version(_), do: "1.0"
  end

  defimpl Measurable do
    def size(%Types.Rectangle{width: w, height: h}), do: w * h
    def empty?(%Types.Rectangle{width: w, height: h}), do: w == 0 or h == 0
  end

end

defmodule Types.Color do
  @moduledoc "An RGB color value."

  defstruct [:r, :g, :b, :a]

  @type t :: %__MODULE__{r: 0..255, g: 0..255, b: 0..255, a: float()}

  def new(r, g, b, a \\ 1.0) do
    %__MODULE__{r: clamp(r), g: clamp(g), b: clamp(b), a: clamp_float(a)}
  end

  def from_hex("#" <> hex) when byte_size(hex) == 6 do
    <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>> = hex
    new(
      String.to_integer(r, 16),
      String.to_integer(g, 16),
      String.to_integer(b, 16)
    )
  end

  def to_hex(%__MODULE__{r: r, g: g, b: b}) do
    "#" <> Base.encode16(<<r, g, b>>, case: :lower)
  end

  def blend(%__MODULE__{r: r1, g: g1, b: b1}, %__MODULE__{r: r2, g: g2, b: b2}, t) do
    lerp = fn a, b -> round(a + (b - a) * t) end
    new(lerp.(r1, r2), lerp.(g1, g2), lerp.(b1, b2))
  end

  defp clamp(n),       do: max(0, min(255, n))
  defp clamp_float(f), do: max(0.0, min(1.0, f))

  defimpl Printable do
    def to_string(%Types.Color{r: r, g: g, b: b, a: 1.0}),
      do: "rgb(#{r}, #{g}, #{b})"
    def to_string(%Types.Color{r: r, g: g, b: b, a: a}),
      do: "rgba(#{r}, #{g}, #{b}, #{a})"
  end

end

# ── Behaviours ────────────────────────────────────────────────────────────

defmodule Behaviour.Storage do
  @moduledoc "Behaviour for pluggable storage backends."

  @callback put(key :: any(), value :: any()) :: :ok | {:error, term()}
  @callback get(key :: any())                 :: {:ok, any()} | {:error, :not_found}
  @callback delete(key :: any())              :: :ok
  @callback list_keys()                       :: [any()]
  @callback clear()                           :: :ok

  @optional_callbacks [clear: 0]
end

defmodule Behaviour.MemoryStorage do
  @moduledoc "In-memory implementation of the Storage behaviour."
  @behaviour Behaviour.Storage

  use Agent

  def start_link(_opts \\ []) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  @impl Behaviour.Storage
  def put(key, value) do
    Agent.update(__MODULE__, fn state -> Map.put(state, key, value) end)
  end

  @impl Behaviour.Storage
  def get(key) do
    case Agent.get(__MODULE__, fn state -> Map.get(state, key) end) do
      nil   -> {:error, :not_found}
      value -> {:ok, value}
    end
  end

  @impl Behaviour.Storage
  def delete(key) do
    Agent.update(__MODULE__, fn state -> Map.delete(state, key) end)
  end

  @impl Behaviour.Storage
  def list_keys() do
    Agent.get(__MODULE__, fn state -> Map.keys(state) end)
  end

  @impl Behaviour.Storage
  def clear() do
    Agent.update(__MODULE__, fn _state -> %{} end)
  end

end

# ── Metaprogramming helpers ───────────────────────────────────────────────

defmodule Meta.Validators do
  @moduledoc """
  Macro-generated validators.
  Covers: defmacro, quote, unquote, __ENV__, @moduledoc injection.
  """

  defmacro defvalidator(name, do: block) do
    quote do
      def unquote(name)(value) do
        unquote(block)
      end
    end
  end

  defmacro assert_type(value, type) do
    quote do
      unless is_struct(unquote(value), unquote(type)) do
        raise ArgumentError,
          "Expected %#{unquote(type)}{}, got: #{inspect(unquote(value))}"
      end
    end
  end

end

defmodule Meta.Schema do
  @moduledoc """
  A lightweight schema / validation library built with macros.
  Shows: module attributes accumulation, __before_compile__, @fields.
  """

  defmacro __using__(_opts) do
    quote do
      import Meta.Schema, only: [field: 2, field: 3]
      Module.register_attribute(__MODULE__, :schema_fields, accumulate: true)
      @before_compile Meta.Schema
    end
  end

  defmacro field(name, type, opts \\ []) do
    quote do
      @schema_fields {unquote(name), unquote(type), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    fields = Module.get_attribute(env.module, :schema_fields) |> Enum.reverse()

    field_names    = Enum.map(fields, fn {name, _type, _opts} -> name end)
    required_names = for {name, _t, opts} <- fields, opts[:required], do: name

    quote do
      defstruct unquote(field_names)

      def __fields__(),   do: unquote(fields)
      def __required__(), do: unquote(required_names)

      def validate(%__MODULE__{} = struct) do
        errors =
          unquote(required_names)
          |> Enum.reduce([], fn field, acc ->
               if Map.get(struct, field) == nil do
                 [{field, "is required"} | acc]
               else
                 acc
               end
             end)
        case errors do
          [] -> {:ok, struct}
          _  -> {:error, errors}
        end
      end
    end
  end

end

defmodule Meta.ExampleSchema do
  use Meta.Schema

  field :name,  :string,  required: true
  field :email, :string,  required: true
  field :age,   :integer
  field :role,  :atom,    default: :user
end

# ── Enum and Stream pipelines ─────────────────────────────────────────────

defmodule Pipelines.Examples do
  @moduledoc "Examples of complex Enum / Stream pipelines."

  # Word frequency count
  def word_frequency(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> -count end)
  end

  # Running average using Stream.scan
  def running_average(numbers) do
    numbers
    |> Stream.scan({0, 0}, fn x, {sum, count} -> {sum + x, count + 1} end)
    |> Stream.map(fn {sum, count} -> sum / count end)
    |> Enum.to_list()
  end

  # Flatten and deduplicate nested lists
  def flatten_unique(nested) do
    nested
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Group consecutive elements
  def chunk_by_sign(numbers) do
    numbers
    |> Enum.chunk_by(fn n -> if n >= 0, do: :positive, else: :negative end)
  end

  # Zip two streams together with index
  def indexed_zip(list_a, list_b) do
    list_a
    |> Stream.zip(list_b)
    |> Stream.with_index()
    |> Enum.map(fn {{a, b}, i} -> {i, a, b} end)
  end

  # Sliding window of size n
  def sliding_window(list, n) do
    list
    |> Enum.chunk_every(n, 1, :discard)
  end

  # Transpose a matrix (list of lists)
  def transpose([[] | _]), do: []
  def transpose(matrix) do
    [Enum.map(matrix, &hd/1) | transpose(Enum.map(matrix, &tl/1))]
  end

end
