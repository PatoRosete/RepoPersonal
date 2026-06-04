# Exercise 2 - Sum of prime numbers <= n
# Uses trial division up to sqrt(x) to identify primes.
#
# Example: sum of primes <= 10 = 2 + 3 + 5 + 7 = 17
#
# Carlos Enrique Rosete Pascual
# 2026-06-03

defmodule Ex2 do

  # Return true if x is prime, false otherwise
  # We use i * i <= x instead of computing sqrt to avoid floats
  def prime?(x) when x < 2, do: false
  def prime?(2), do: true
  def prime?(x) do
    check_divisors(x, 2)
  end

  defp check_divisors(x, i) when i * i > x, do: true
  defp check_divisors(x, i) do
    if rem(x, i) == 0, do: false, else: check_divisors(x, i + 1)
  end

  # Sum all primes in a {start, finish} range (receives a tuple)
  def sum_primes_range({start, finish}) do
    start..finish
    |> Enum.filter(&prime?/1)
    |> Enum.sum()
  end

  # Compute the sum of all primes <= n sequentially and print the time
  def sum_primes(n) do
    {time, result} = :timer.tc(fn ->
      2..n
      |> Enum.filter(&prime?/1)
      |> Enum.sum()
    end)
    IO.puts("SEQUENTIAL | N: #{n} | Sum: #{result} | Time: #{time / 1_000_000} s")
    result
  end

  # Compute the sum of all primes <= n in parallel using t tasks and print the time
  def parallel_sum_primes(n, t \\ System.schedulers()) do
    {time, result} = :timer.tc(fn ->
      step     = ceil(n / t)
      starts   = [2 | Enum.to_list((step + 1)..n//step)]
      # Force the last finish to be n so no numbers are left out
      finishes = Enum.to_list(step..n//step) |> List.replace_at(-1, n)

      Enum.zip(starts, finishes)
      |> IO.inspect()
      |> Enum.map(&Task.async(fn -> sum_primes_range(&1) end))
      |> Enum.map(&Task.await(&1, :infinity))
      |> Enum.sum()
    end)
    IO.puts("PARALLEL   | N: #{n} | Sum: #{result} | Time: #{time / 1_000_000} s")
    result
  end

end
