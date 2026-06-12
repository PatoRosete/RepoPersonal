# Pattern matching, guards, with, comprehensions, streams, and sigils
#
# This file is deliberately dense with varied syntax so every
# token type gets exercised: atoms, sigils, captures, ignored vars,
# hex numbers, binary syntax, triple strings, and more.

defmodule Patterns.Guards do
  @moduledoc """
  Demonstrates guards, multi-clause functions, and pattern matching
  on various data types.
  """

  # Guards with multiple conditions
  def classify_number(n) when is_integer(n) and n < 0,      do: :negative_integer
  def classify_number(n) when is_integer(n) and n == 0,     do: :zero
  def classify_number(n) when is_integer(n) and rem(n, 2) == 0, do: :positive_even
  def classify_number(n) when is_integer(n),                do: :positive_odd
  def classify_number(n) when is_float(n) and n < 0.0,      do: :negative_float
  def classify_number(n) when is_float(n),                  do: :positive_float
  def classify_number(_),                                   do: :not_a_number

  # Pattern matching on tuples
  def handle_result({:ok, value}),        do: "Success: #{inspect(value)}"
  def handle_result({:error, reason}),    do: "Error: #{inspect(reason)}"
  def handle_result({:error, code, msg}), do: "Error #{code}: #{msg}"
  def handle_result(:timeout),            do: "Request timed out"
  def handle_result(other),               do: "Unknown: #{inspect(other)}"

  # Pattern matching on lists
  def head([]),        do: nil
  def head([h | _]),   do: h

  def tail([]),        do: []
  def tail([_ | t]),   do: t

  def last([x]),       do: x
  def last([_ | t]),   do: last(t)

  def take(_, 0),       do: []
  def take([], _),      do: []
  def take([h | t], n), do: [h | take(t, n - 1)]

  def drop(list, 0),   do: list
  def drop([], _),     do: []
  def drop([_ | t], n), do: drop(t, n - 1)

  # Pattern matching on maps
  def greet(%{name: name, role: :admin}),  do: "Hello, Admin #{name}!"
  def greet(%{name: name, role: :guest}),  do: "Welcome, guest #{name}."
  def greet(%{name: name}),               do: "Hi, #{name}."
  def greet(_),                            do: "Hi there."

  # Pattern matching on binaries
  def parse_ip(<<a, ?., b, ?., c, ?., d>>) do
    {:ok, {a - ?0, b - ?0, c - ?0, d - ?0}}
  end
  def parse_ip(_), do: {:error, :invalid_ip}

  def parse_header(<<"GET ", rest::binary>>),    do: {:get, rest}
  def parse_header(<<"POST ", rest::binary>>),   do: {:post, rest}
  def parse_header(<<"DELETE ", rest::binary>>), do: {:delete, rest}
  def parse_header(other),                       do: {:unknown, other}

end

defmodule Patterns.WithExamples do
  @moduledoc """
  Real-world patterns using `with` for happy-path pipelines.
  """

  def create_user(params) do
    with {:ok, name}  <- validate_name(params[:name]),
         {:ok, email} <- validate_email(params[:email]),
         {:ok, age}   <- validate_age(params[:age]),
         {:ok, user}  <- persist_user(%{name: name, email: email, age: age}) do
      {:ok, user}
    else
      {:error, :missing_name}  -> {:error, "Name is required"}
      {:error, :invalid_email} -> {:error, "Email is not valid"}
      {:error, :underage}      -> {:error, "Must be 18 or older"}
      {:error, reason}         -> {:error, "Unexpected error: #{inspect(reason)}"}
    end
  end

  defp validate_name(nil),                    do: {:error, :missing_name}
  defp validate_name(""),                     do: {:error, :missing_name}
  defp validate_name(name) when is_binary(name), do: {:ok, String.trim(name)}

  defp validate_email(email) when is_binary(email) do
    if Regex.match?(~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/, email) do
      {:ok, String.downcase(email)}
    else
      {:error, :invalid_email}
    end
  end
  defp validate_email(_), do: {:error, :invalid_email}

  defp validate_age(age) when is_integer(age) and age >= 18, do: {:ok, age}
  defp validate_age(age) when is_integer(age),               do: {:error, :underage}
  defp validate_age(_),                                      do: {:error, :invalid_age}

  defp persist_user(user), do: {:ok, Map.put(user, :id, :rand.uniform(999_999))}

end

defmodule Patterns.Comprehensions do
  @moduledoc """
  List comprehensions and for expressions.
  Covers: for, generators, filters, into, reduce.
  """

  # Simple comprehension
  def squares(n) do
    for x <- 1..n, do: x * x
  end

  # Comprehension with filter
  def even_squares(n) do
    for x <- 1..n, rem(x, 2) == 0, do: x * x
  end

  # Nested comprehensions (cartesian product)
  def cartesian(xs, ys) do
    for x <- xs, y <- ys, do: {x, y}
  end

  # Pythagorean triples up to n
  def pythagorean_triples(n) do
    for a <- 1..n,
        b <- a..n,
        c = :math.sqrt(a * a + b * b),
        trunc(c) == c and c <= n,
        do: {a, b, trunc(c)}
  end

  # Comprehension into a map
  def index_by(list, key_fn) do
    for item <- list, into: %{}, do: {key_fn.(item), item}
  end

  # Comprehension with reduce (sum of squares)
  def sum_of_squares(n) do
    for x <- 1..n, reduce: 0 do
      acc -> acc + x * x
    end
  end

  # Matrix multiplication
  def matrix_multiply(a, b) do
    cols_b = Enum.zip(b) |> Enum.map(&Tuple.to_list/1)
    for row <- a do
      for col <- cols_b do
        Enum.zip(row, col)
        |> Enum.map(fn {x, y} -> x * y end)
        |> Enum.sum()
      end
    end
  end

end

defmodule Patterns.Strings do
  @moduledoc """
  String manipulation and sigils.
  Covers: ~r, ~s, ~w, ~c, heredocs, binary pattern matching.
  """

  # Word list sigil
  @days_of_week ~w(monday tuesday wednesday thursday friday saturday sunday)a
  @months       ~w(january february march april may june
                   july august september october november december)

  def day_number(day) do
    Enum.find_index(@days_of_week, &(&1 == String.to_atom(day)))
    |> case do
      nil -> {:error, :unknown_day}
      n   -> {:ok, n + 1}
    end
  end

  def month_number(month) do
    Enum.find_index(@months, &(&1 == String.downcase(month)))
    |> case do
      nil -> {:error, :unknown_month}
      n   -> {:ok, n + 1}
    end
  end

  # Regex sigil
  @email_regex    ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/
  @phone_regex    ~r/^\+?[\d\s\-\(\)]{7,15}$/
  @slug_regex     ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/
  @hex_color      ~r/^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/

  def valid_email?(email),  do: Regex.match?(@email_regex, email)
  def valid_phone?(phone),  do: Regex.match?(@phone_regex, phone)
  def valid_slug?(slug),    do: Regex.match?(@slug_regex, slug)
  def valid_hex_color?(hex), do: Regex.match?(@hex_color, hex)

  # Heredoc string
  def help_text() do
    """
    Usage: my_program [OPTIONS] FILE

    Options:
      --verbose, -v   Enable verbose output
      --output, -o    Specify output file (default: stdout)
      --help, -h      Show this help message

    Examples:
      my_program input.exs
      my_program --verbose --output result.html input.exs
    """
  end

  # Slugify a string
  def slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/[\s_-]+/, "-")
    |> String.trim("-")
  end

  # Truncate with ellipsis
  def truncate(text, max_length, ellipsis \\ "…") do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length - String.length(ellipsis)) <> ellipsis
    end
  end

  # Simple template interpolation
  def interpolate(template, bindings) do
    Regex.replace(~r/\{\{(\w+)\}\}/, template, fn _, key ->
      to_string(bindings[String.to_atom(key)] || "")
    end)
  end

end

defmodule Patterns.Numbers do
  @moduledoc """
  Numeric operations with varied literal formats.
  Covers: hex 0xFF, octal 0o77, binary 0b1010, scientific 1.5e10,
  underscore separators 1_000_000, integer math, float math.
  """

  # Some interesting numeric constants
  @max_uint8   0xFF
  @max_uint16  0xFFFF
  @max_uint32  0xFFFF_FFFF
  @octal_perm  0o755
  @binary_mask 0b1111_0000
  @million     1_000_000
  @pi          3.141_592_653_589_793
  @avogadro    6.022e23
  @planck      6.626e-34

  def constants(), do: %{
    max_uint8:   @max_uint8,
    max_uint16:  @max_uint16,
    max_uint32:  @max_uint32,
    octal_perm:  @octal_perm,
    binary_mask: @binary_mask,
    million:     @million,
    pi:          @pi,
    avogadro:    @avogadro,
    planck:      @planck
  }

  # Bitwise operations
  def set_bit(n, pos),    do: n ||| (1 <<< pos)
  def clear_bit(n, pos),  do: n &&& ~~~(1 <<< pos)
  def toggle_bit(n, pos), do: n ^^^ (1 <<< pos)
  def test_bit(n, pos),   do: (n >>> pos &&& 1) == 1

  # Integer operations
  def gcd(a, 0), do: abs(a)
  def gcd(a, b), do: gcd(b, rem(a, b))

  def lcm(a, b), do: div(abs(a * b), gcd(a, b))

  def factorial(0), do: 1
  def factorial(n) when n > 0, do: n * factorial(n - 1)

  def fibonacci(n), do: fib(n, 0, 1)
  defp fib(0, a, _), do: a
  defp fib(n, a, b), do: fib(n - 1, b, a + b)

  # Float operations
  def nearly_equal?(a, b, epsilon \\ 1.0e-9) do
    abs(a - b) < epsilon
  end

  def clamp(value, min, max) do
    value |> max(min) |> min(max)
  end

  def lerp(a, b, t), do: a + (b - a) * t

  def degrees_to_radians(deg), do: deg * @pi / 180.0
  def radians_to_degrees(rad), do: rad * 180.0 / @pi

  # Statistics
  def mean([]),   do: nil
  def mean(list), do: Enum.sum(list) / length(list)

  def variance(list) do
    m = mean(list)
    list
    |> Enum.map(fn x -> :math.pow(x - m, 2) end)
    |> mean()
  end

  def std_dev(list), do: list |> variance() |> :math.sqrt()

  def median(list) do
    sorted = Enum.sort(list)
    n      = length(sorted)
    mid    = div(n, 2)
    if rem(n, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end

end
