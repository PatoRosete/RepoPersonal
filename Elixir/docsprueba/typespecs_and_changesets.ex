# Typespecs, doctests, changesets, and diverse Elixir syntax
#
# This file covers: @type, @spec, @doc with doctests, structs,
# keyword lists, map operations, string interpolation, atoms as keys,
# anonymous functions as captures, and more.

defmodule Types.Specs do
  @moduledoc """
  Examples of typespecs: @type, @typep, @opaque, @spec.
  """

  @type  id          :: pos_integer()
  @type  name        :: String.t()
  @type  email       :: String.t()
  @type  maybe(t)    :: {:ok, t} | {:error, term()}
  @typep internal_id :: binary()

  @opaque token :: %{
    value:      binary(),
    expires_at: DateTime.t(),
    scopes:     [atom()]
  }

  @type  user :: %{
    id:    id(),
    name:  name(),
    email: email(),
    role:  :admin | :user | :guest
  }

  @spec  greet(name())                        :: String.t()
  @spec  add(number(), number())              :: number()
  @spec  divide(number(), number())           :: maybe(float())
  @spec  find(list(any()), (any() -> boolean())) :: {:ok, any()} | :not_found

  @doc """
  Greet a user by name.

  ## Examples

      iex> Types.Specs.greet("Alice")
      "Hello, Alice!"

      iex> Types.Specs.greet("World")
      "Hello, World!"

  """
  def greet(name), do: "Hello, #{name}!"

  @doc """
  Add two numbers.

  ## Examples

      iex> Types.Specs.add(1, 2)
      3

      iex> Types.Specs.add(1.5, 2.5)
      4.0

  """
  def add(a, b), do: a + b

  @doc """
  Divide two numbers, returning an error for division by zero.

  ## Examples

      iex> Types.Specs.divide(10, 2)
      {:ok, 5.0}

      iex> Types.Specs.divide(1, 0)
      {:error, :division_by_zero}

  """
  def divide(_a, 0),  do: {:error, :division_by_zero}
  def divide(a, b),   do: {:ok, a / b}

  @doc """
  Find the first element in `list` matching `predicate`.

  ## Examples

      iex> Types.Specs.find([1, 2, 3], &(&1 > 1))
      {:ok, 2}

      iex> Types.Specs.find([1, 2, 3], &(&1 > 10))
      :not_found

  """
  def find(list, predicate) do
    case Enum.find(list, predicate) do
      nil   -> :not_found
      value -> {:ok, value}
    end
  end

end

defmodule Changeset do
  @moduledoc """
  A lightweight changeset system (inspired by Ecto.Changeset).
  Covers: structs, keyword lists, reduce, pattern matching on maps.
  """

  defstruct [:data, :changes, :errors, :valid?]

  @type t :: %__MODULE__{
    data:    map(),
    changes: map(),
    errors:  keyword(),
    valid?:  boolean()
  }

  # Create a new changeset
  def change(data, params \\ %{}) do
    %__MODULE__{
      data:    data,
      changes: params,
      errors:  [],
      valid?:  true
    }
  end

  # Cast allowed fields
  def cast(%__MODULE__{changes: changes} = cs, params, allowed_fields) do
    new_changes =
      allowed_fields
      |> Enum.reduce(changes, fn field, acc ->
           key = if is_atom(field), do: field, else: String.to_atom(field)
           str_key = to_string(field)
           case Map.get(params, key) || Map.get(params, str_key) do
             nil   -> acc
             value -> Map.put(acc, key, value)
           end
         end)
    %{cs | changes: new_changes}
  end

  # Validate required fields
  def validate_required(%__MODULE__{changes: changes} = cs, fields) do
    errors =
      fields
      |> Enum.reduce(cs.errors, fn field, acc ->
           value = Map.get(changes, field)
           if is_nil(value) or value == "" do
             [{field, "can't be blank"} | acc]
           else
             acc
           end
         end)
    %{cs | errors: errors, valid?: errors == []}
  end

  # Validate string length
  def validate_length(%__MODULE__{changes: changes} = cs, field, opts) do
    value = Map.get(changes, field, "")
    len   = String.length(to_string(value))
    min   = Keyword.get(opts, :min)
    max   = Keyword.get(opts, :max)

    error =
      cond do
        min && len < min -> "should be at least #{min} character(s)"
        max && len > max -> "should be at most #{max} character(s)"
        true             -> nil
      end

    if error do
      %{cs | errors: [{field, error} | cs.errors], valid?: false}
    else
      cs
    end
  end

  # Validate format with regex
  def validate_format(%__MODULE__{changes: changes} = cs, field, regex, message \\ "has invalid format") do
    value = to_string(Map.get(changes, field, ""))
    if Regex.match?(regex, value) do
      cs
    else
      %{cs | errors: [{field, message} | cs.errors], valid?: false}
    end
  end

  # Validate inclusion
  def validate_inclusion(%__MODULE__{changes: changes} = cs, field, allowed) do
    value = Map.get(changes, field)
    if value in allowed do
      cs
    else
      %{cs | errors: [{field, "is not a valid value"} | cs.errors], valid?: false}
    end
  end

  # Apply changes if valid
  def apply_changes(%__MODULE__{valid?: false} = cs), do: {:error, cs}
  def apply_changes(%__MODULE__{data: data, changes: changes}) do
    {:ok, Map.merge(data, changes)}
  end

end

defmodule Config.Parser do
  @moduledoc """
  A simple configuration file parser.
  Covers: String operations, atoms, keyword lists, sigils, and maps.
  """

  @comment_regex  ~r/^\s*#/
  @section_regex  ~r/^\s*\[(\w+)\]\s*$/
  @kv_regex       ~r/^\s*(\w+)\s*=\s*(.+?)\s*$/

  def parse(text) do
    text
    |> String.split("\n")
    |> Enum.reduce({:root, %{}}, fn line, {section, acc} ->
         cond do
           Regex.match?(@comment_regex, line) ->
             {section, acc}

           match = Regex.run(@section_regex, line) ->
             [_, name] = match
             new_section = String.to_atom(name)
             {new_section, Map.put_new(acc, new_section, %{})}

           match = Regex.run(@kv_regex, line) ->
             [_, key, value] = match
             k = String.to_atom(key)
             v = parse_value(value)
             updated = Map.update(acc, section, %{k => v}, fn s -> Map.put(s, k, v) end)
             {section, updated}

           true ->
             {section, acc}
         end
       end)
    |> then(fn {_section, result} -> result end)
  end

  defp parse_value("true"),  do: true
  defp parse_value("false"), do: false
  defp parse_value("nil"),   do: nil
  defp parse_value(value) do
    cond do
      Regex.match?(~r/^\d+$/, value)        -> String.to_integer(value)
      Regex.match?(~r/^\d+\.\d+$/, value)   -> String.to_float(value)
      Regex.match?(~r/^"(.+)"$/, value)     ->
        [_, inner] = Regex.run(~r/^"(.+)"$/, value)
        inner
      true -> value
    end
  end

end

defmodule Dates.Utils do
  @moduledoc """
  Date and time utilities.
  Covers: Date, Time, DateTime, NaiveDateTime, sigils ~D, ~T, ~U.
  """

  # Date literals using sigils
  @epoch       ~D[1970-01-01]
  @sample_time ~T[12:00:00]
  @sample_dt   ~U[2026-01-01 00:00:00Z]

  def days_since_epoch(date) do
    Date.diff(date, @epoch)
  end

  def is_weekend?(date) do
    Date.day_of_week(date) in [6, 7]
  end

  def next_weekday(date) do
    next = Date.add(date, 1)
    if is_weekend?(next), do: next_weekday(next), else: next
  end

  def business_days_between(start_date, end_date) do
    start_date
    |> Date.range(end_date)
    |> Enum.count(fn d -> not is_weekend?(d) end)
  end

  def format_date(date, format \\ :iso) do
    case format do
      :iso   -> Date.to_iso8601(date)
      :human -> "#{date.day} #{month_name(date.month)} #{date.year}"
      :short -> "#{date.day}/#{date.month}/#{date.year}"
    end
  end

  defp month_name(1),  do: "January"
  defp month_name(2),  do: "February"
  defp month_name(3),  do: "March"
  defp month_name(4),  do: "April"
  defp month_name(5),  do: "May"
  defp month_name(6),  do: "June"
  defp month_name(7),  do: "July"
  defp month_name(8),  do: "August"
  defp month_name(9),  do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"

  def age_in_years(birth_date) do
    today = Date.utc_today()
    years = today.year - birth_date.year
    if {today.month, today.day} < {birth_date.month, birth_date.day} do
      years - 1
    else
      years
    end
  end

end
