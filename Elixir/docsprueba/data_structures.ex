# Data structures and algorithms in Elixir
#
# This file covers: modules, structs, protocols, pattern matching,
# recursion, list comprehensions, streams, and more.

defmodule DataStructures.LinkedList do
  @moduledoc """
  A simple singly linked list implemented with structs and recursion.
  Covers: defstruct, pattern matching, recursion, guards.
  """

  defstruct [:head, :tail]

  @type t :: %__MODULE__{head: any(), tail: t() | nil}

  # Build a linked list from a plain Elixir list
  def from_list([]), do: nil
  def from_list([h | t]), do: %__MODULE__{head: h, tail: from_list(t)}

  # Convert back to a plain list
  def to_list(nil), do: []
  def to_list(%__MODULE__{head: h, tail: t}), do: [h | to_list(t)]

  # Length – recursive
  def length(nil), do: 0
  def length(%__MODULE__{tail: t}), do: 1 + length(t)

  # Prepend an element
  def prepend(list, value), do: %__MODULE__{head: value, tail: list}

  # Append an element (O(n))
  def append(nil, value), do: %__MODULE__{head: value, tail: nil}
  def append(%__MODULE__{head: h, tail: t}, value) do
    %__MODULE__{head: h, tail: append(t, value)}
  end

  # Map over the list
  def map(nil, _fun), do: nil
  def map(%__MODULE__{head: h, tail: t}, fun) do
    %__MODULE__{head: fun.(h), tail: map(t, fun)}
  end

  # Filter elements
  def filter(nil, _pred), do: nil
  def filter(%__MODULE__{head: h, tail: t}, pred) do
    if pred.(h) do
      %__MODULE__{head: h, tail: filter(t, pred)}
    else
      filter(t, pred)
    end
  end

  # Reduce / fold left
  def reduce(nil, acc, _fun), do: acc
  def reduce(%__MODULE__{head: h, tail: t}, acc, fun) do
    reduce(t, fun.(acc, h), fun)
  end

  # Reverse
  def reverse(list), do: reverse(list, nil)
  defp reverse(nil, acc), do: acc
  defp reverse(%__MODULE__{head: h, tail: t}, acc) do
    reverse(t, %__MODULE__{head: h, tail: acc})
  end

end

defmodule DataStructures.BinaryTree do
  @moduledoc """
  A binary search tree.
  Covers: recursive structs, pattern matching on maps, guards.
  """

  defstruct [:value, :left, :right]

  @type t :: %__MODULE__{value: any(), left: t() | nil, right: t() | nil}

  def new(value), do: %__MODULE__{value: value, left: nil, right: nil}

  def insert(nil, value), do: new(value)
  def insert(%__MODULE__{value: v} = node, value) when value < v do
    %{node | left: insert(node.left, value)}
  end
  def insert(%__MODULE__{value: v} = node, value) when value > v do
    %{node | right: insert(node.right, value)}
  end
  def insert(node, _value), do: node   # already exists

  def member?(nil, _value), do: false
  def member?(%__MODULE__{value: v}, value) when value == v, do: true
  def member?(%__MODULE__{value: v, left: l}, value) when value < v, do: member?(l, value)
  def member?(%__MODULE__{right: r}, value), do: member?(r, value)

  # In-order traversal produces a sorted list
  def inorder(nil), do: []
  def inorder(%__MODULE__{value: v, left: l, right: r}) do
    inorder(l) ++ [v] ++ inorder(r)
  end

  def height(nil), do: 0
  def height(%__MODULE__{left: l, right: r}) do
    1 + max(height(l), height(r))
  end

  def from_list(list) do
    Enum.reduce(list, nil, fn val, tree -> insert(tree, val) end)
  end

end

defmodule DataStructures.Sorting do
  @moduledoc """
  Classic sorting algorithms.
  Covers: recursion, list comprehensions, pattern matching, guards.
  """

  # Merge sort
  def merge_sort([]), do: []
  def merge_sort([x]), do: [x]
  def merge_sort(list) do
    mid = div(length(list), 2)
    {left, right} = Enum.split(list, mid)
    merge(merge_sort(left), merge_sort(right))
  end

  defp merge([], right), do: right
  defp merge(left, []), do: left
  defp merge([h1 | t1], [h2 | _] = right) when h1 <= h2 do
    [h1 | merge(t1, right)]
  end
  defp merge(left, [h2 | t2]) do
    [h2 | merge(left, t2)]
  end

  # Quick sort
  def quick_sort([]), do: []
  def quick_sort([pivot | rest]) do
    smaller = for x <- rest, x <= pivot, do: x
    greater = for x <- rest, x > pivot,  do: x
    quick_sort(smaller) ++ [pivot] ++ quick_sort(greater)
  end

  # Bubble sort (educational, not efficient)
  def bubble_sort(list) do
    n = length(list)
    Enum.reduce(1..n, list, fn _, acc -> bubble_pass(acc) end)
  end

  defp bubble_pass([]), do: []
  defp bubble_pass([x]), do: [x]
  defp bubble_pass([a, b | rest]) when a > b do
    [b | bubble_pass([a | rest])]
  end
  defp bubble_pass([a | rest]) do
    [a | bubble_pass(rest)]
  end

  # Insertion sort
  def insertion_sort([]), do: []
  def insertion_sort([h | t]) do
    insert_sorted(h, insertion_sort(t))
  end

  defp insert_sorted(x, []), do: [x]
  defp insert_sorted(x, [h | _] = sorted) when x <= h, do: [x | sorted]
  defp insert_sorted(x, [h | t]), do: [h | insert_sorted(x, t)]

end

defmodule DataStructures.Graph do
  @moduledoc """
  A simple directed graph represented as an adjacency map.
  Covers: maps, MapSet, recursion, BFS, DFS.
  """

  @type t :: %{any() => MapSet.t()}

  def new(), do: %{}

  def add_vertex(graph, v), do: Map.put_new(graph, v, MapSet.new())

  def add_edge(graph, from, to) do
    graph
    |> add_vertex(from)
    |> add_vertex(to)
    |> Map.update!(from, fn neighbors -> MapSet.put(neighbors, to) end)
  end

  def neighbors(graph, v), do: Map.get(graph, v, MapSet.new())

  # Depth-first search – returns list of visited nodes
  def dfs(graph, start) do
    dfs(graph, [start], MapSet.new(), [])
  end

  defp dfs(_graph, [], _visited, acc), do: Enum.reverse(acc)
  defp dfs(graph, [current | stack], visited, acc) do
    if MapSet.member?(visited, current) do
      dfs(graph, stack, visited, acc)
    else
      new_visited = MapSet.put(visited, current)
      new_stack   = MapSet.to_list(neighbors(graph, current)) ++ stack
      dfs(graph, new_stack, new_visited, [current | acc])
    end
  end

  # Breadth-first search
  def bfs(graph, start) do
    bfs(graph, :queue.from_list([start]), MapSet.new([start]), [])
  end

  defp bfs(_graph, {[], []}, _visited, acc), do: Enum.reverse(acc)
  defp bfs(graph, queue, visited, acc) do
    {{:value, current}, rest_queue} = :queue.out(queue)
    new_neighbors =
      graph
      |> neighbors(current)
      |> MapSet.difference(visited)
      |> MapSet.to_list()

    new_queue   = Enum.reduce(new_neighbors, rest_queue, &:queue.in(&1, &2))
    new_visited = MapSet.union(visited, MapSet.new(new_neighbors))
    bfs(graph, new_queue, new_visited, [current | acc])
  end

end

defmodule DataStructures.Stack do
  @moduledoc "A simple stack backed by a list."

  defstruct items: []

  def new(), do: %__MODULE__{}
  def push(%__MODULE__{items: items}, value), do: %__MODULE__{items: [value | items]}
  def pop(%__MODULE__{items: []}),            do: {:error, :empty}
  def pop(%__MODULE__{items: [top | rest]}),  do: {:ok, top, %__MODULE__{items: rest}}
  def peek(%__MODULE__{items: []}),           do: {:error, :empty}
  def peek(%__MODULE__{items: [top | _]}),    do: {:ok, top}
  def empty?(%__MODULE__{items: []}),         do: true
  def empty?(_),                              do: false
  def size(%__MODULE__{items: items}),        do: length(items)
end

defmodule DataStructures.Queue do
  @moduledoc "A double-ended queue using two lists."

  defstruct front: [], back: []

  def new(), do: %__MODULE__{}

  def enqueue(%__MODULE__{back: back} = q, value) do
    %{q | back: [value | back]}
  end

  def dequeue(%__MODULE__{front: [], back: []}), do: {:error, :empty}
  def dequeue(%__MODULE__{front: [], back: back} = q) do
    [head | rest] = Enum.reverse(back)
    {:ok, head, %{q | front: rest, back: []}}
  end
  def dequeue(%__MODULE__{front: [head | rest]} = q) do
    {:ok, head, %{q | front: rest}}
  end

  def size(%__MODULE__{front: f, back: b}), do: length(f) + length(b)
end

defmodule DataStructures.Trie do
  @moduledoc """
  A trie (prefix tree) for string keys.
  Covers: recursive maps, String.graphemes/1, reduce.
  """

  defstruct children: %{}, is_end: false

  def new(), do: %__MODULE__{}

  def insert(trie, word) do
    chars = String.graphemes(word)
    do_insert(trie, chars)
  end

  defp do_insert(trie, []) do
    %{trie | is_end: true}
  end
  defp do_insert(%__MODULE__{children: children} = trie, [char | rest]) do
    child    = Map.get(children, char, new())
    updated  = do_insert(child, rest)
    %{trie | children: Map.put(children, char, updated)}
  end

  def search(trie, word) do
    chars = String.graphemes(word)
    case do_search(trie, chars) do
      %__MODULE__{is_end: true} -> true
      _                         -> false
    end
  end

  defp do_search(trie, []), do: trie
  defp do_search(%__MODULE__{children: children}, [char | rest]) do
    case Map.get(children, char) do
      nil   -> nil
      child -> do_search(child, rest)
    end
  end

  def starts_with?(trie, prefix) do
    chars = String.graphemes(prefix)
    do_search(trie, chars) != nil
  end

end
