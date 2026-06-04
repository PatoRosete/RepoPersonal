# Exercise 1 - Bits set to 1 in n!
# Computes n! and returns the count of bits equal to 1
# in the binary representation of the result.
#
# Example: 6! = 720 = 1011010000b -> 4 bits set to 1
#
# Carlos Enrique Rosete Pascual
# 2026-06-03

defmodule Ex1 do

  # Count the number of bits set to 1 in an integer
  def count_bits(n), do: count_bits(n, 0)
  defp count_bits(0, acc), do: acc
  defp count_bits(n, acc), do: count_bits(div(n, 2), acc + rem(n, 2))

  # Multiply all numbers in a range (receives a {start, finish} tuple)
  def multiply_range({start, finish}) do
    Enum.product(start..finish)
  end

  # Compute n! sequentially, print factorial, binary, bits, and time
  def factorial_bits(n) do
    {time, result} = :timer.tc(fn -> Enum.product(1..n) end)
    binary = Integer.to_string(result, 2)
    bits   = count_bits(result)
    IO.puts("SEQUENTIAL | N: #{n} | N!: #{result} | Binary: #{binary} | Bits: #{bits} | Time: #{time / 1_000_000} s")
    bits
  end

  # Compute n! in parallel using t tasks, print factorial, binary, bits, and time
  def parallel_factorial_bits(n, t \\ System.schedulers()) do
    {time, result} = :timer.tc(fn ->
      step     = ceil(n / t)
      starts   = [1 | Enum.to_list((step + 1)..n//step)]
      # Force the last finish to be n so no numbers are left out
      finishes = Enum.to_list(step..n//step) |> List.replace_at(-1, n)

      Enum.zip(starts, finishes)
      |> IO.inspect()
      |> Enum.map(&Task.async(fn -> multiply_range(&1) end))
      |> Enum.map(&Task.await(&1, :infinity))
      |> Enum.product()
    end)
    binary = Integer.to_string(result, 2)
    bits   = count_bits(result)
    IO.puts("PARALLEL   | N: #{n} | N!: #{result} | Binary: #{binary} | Bits: #{bits} | Time: #{time / 1_000_000} s")
    bits
  end

end
