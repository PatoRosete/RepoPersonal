# Syntax highlighter - Sequential version
#
# Carlos Enrique Rosete Pascual
# 2026-06-11
#

defmodule TecLexer.Sequential do

  # List of Elixir reserved words.
  # Taken from the syntax reference: https://hexdocs.pm/elixir/syntax-reference.html
  @reserved ~w(
    def defp defmodule defmacro defmacrop defprotocol defimpl defstruct defguard defguardp
    do end fn when in not and or
    if else unless cond case with for receive after
    try catch rescue raise throw
    import alias require use
    nil true false
  )

  # Each rule is a tuple: {css_class, regex}.
  # Order matters: the first rule to match at the current position wins.
  # All regexes are anchored at the beginning of the remaining text with \A.
  @rules [
    # Triple-quoted strings must come before regular strings so they match first
    {"string", ~r/\A"{3}[\s\S]*?"{3}/},
    {"string", ~r/\A'{3}[\s\S]*?'{3}/},

    # Single-line comment: from # until end of line
    {"comment", ~r/\A#.*/},

    # Sigils: ~r/regex/, ~s"string", ~w[word list], etc.
    {"sigil", ~r/\A~[a-zA-Z](?:[\/\|"'\(\[\{<])(?:[^\\]|\\.)*?(?:[\/\|"'\)\]\}>])[a-zA-Z]*/},

    # Strings with double quotes (allows escaped characters inside)
    {"string", ~r/\A"(?:[^"\\]|\\.)*"/},

    # Charlists with single quotes
    {"string", ~r/\A'(?:[^'\\]|\\.)*'/},

    # Numbers: hex, octal, binary, floats with exponent, plain floats, integers
    # Longest patterns go first so 0xFF is not confused with 0
    {"number", ~r/\A0x[0-9a-fA-F][0-9a-fA-F_]*/},
    {"number", ~r/\A0o[0-7][0-7_]*/},
    {"number", ~r/\A0b[01][01_]*/},
    {"number", ~r/\A\d[\d_]*\.\d[\d_]*[eE][+-]?\d+/},
    {"number", ~r/\A\d[\d_]*\.\d[\d_]*/},
    {"number", ~r/\A\d[\d_]*[eE][+-]?\d+/},
    {"number", ~r/\A\d[\d_]*/},

    # Atoms: :name or :"quoted name"
    {"atom", ~r/\A:[a-zA-Z_]\w*[?!]?/},
    {"atom", ~r/\A:"(?:[^"\\]|\\.)*"/},

    # Module names: start uppercase, may chain with dots (Enum, IO, File.Stream)
    {"module", ~r/\A[A-Z][a-zA-Z0-9_]*(?:\.[A-Z][a-zA-Z0-9_]*)*/},

    # Module attributes (@doc, @spec, @moduledoc) and special forms (__MODULE__ etc.)
    {"special", ~r/\A@[a-zA-Z_]\w*/},
    {"special", ~r/\A__[A-Z_]+__/},

    # Capture operator: &String.upcase/1, &my_fun/2, &1
    # Longer patterns go first to avoid partial matches
    {"capture", ~r/\A&[A-Z]\w*\.[a-z_]\w*\/\d+/},
    {"capture",  ~r/\A&[a-z_]\w*\/\d+/},
    {"capture", ~r/\A&\d+/},

    # Ignored variables: _ or _name (used in pattern matching to discard values)
    {"ignored", ~r/\A_\w*/},

    # Functions: an identifier immediately followed by ( -- lookahead so the
    # parenthesis is NOT consumed here; it will be matched as punctuation next
    {"function", ~r/\A[a-z_]\w*[?!]?(?=\()/},

    # Identifier: variables, function names, and reserved words.
    # We decide which one it really is in render_token/2.
    {"identifier",  ~r/\A[a-zA-Z_]\w*[?!]?/},

    # Operators (longest first so |> matches before | and >= matches before >)
    {"operator", ~r/\A(?:===|!==|==|!=|<=|>=|->|<-|=>|\|>|<>|\+\+|--|=~|::|\.\.|\*\*|\|\||&&|=|\+|-|\*|\/|<|>|!|&|\^|\||~)/},

    # Punctuation: parens, brackets, braces, comma, semicolon, dot, pipe, colon
    {"punctuation", ~r/\A[\(\)\[\]\{\},%;\.\|:]/}
  ]

  # Public entry point.
  # Receives the directory path as an argument and processes every .ex / .exs
  # file found inside it, writing one HTML file per source file.
  # Prints the total wall-clock time when done.
  def run(directory, output_dir \\ "output_sequential") do
    # Create the output directory if it does not exist yet
    File.mkdir_p!(output_dir)
    {time, _} = :timer.tc(fn ->
      process_directory(directory, output_dir)
    end)
    IO.puts("SEQUENTIAL | Directory: #{directory} | Time: #{time / 1_000_000} s")
  end

  # List all .ex and .exs files in the directory and process them one by one.
  defp process_directory(directory, output_dir) do
    {:ok, entries} = File.ls(directory)
    entries
    |> Enum.filter(fn name ->
      String.ends_with?(name, ".ex") or String.ends_with?(name, ".exs")
    end)
    |> Enum.each(fn name ->
      highlight_file(Path.join(directory, name), output_dir)
    end)
  end

  # Read a single source file, highlight every line, and write the HTML output.
  defp highlight_file(path, output_dir) do
    body = path
      |> File.stream!()
      |> Enum.map(&line_to_html/1)
      |> Enum.join("")

    # Build the output filename: <basename>_sequential.html
    base = Path.basename(path, Path.extname(path))
    out  = Path.join(output_dir, "#{base}_sequential.html")
    File.write!(out, build_html(path, body))
  end

  # Convert a single line of source into a line of HTML.
  defp line_to_html(line) do
    line = String.replace_suffix(line, "\n", "")
    tokenize(line, "") <> "\n"
  end

  # Recursive tokenizer.
  # Base case: nothing left to consume, return the accumulated HTML.
  defp tokenize("", acc), do: acc

  defp tokenize(rest, acc) do
    # Whitespace is not a token so we just copy any leading spaces/tabs
    case Regex.run(~r/\A\s+/, rest) do
      [spaces] ->
        rest_after = String.slice(rest, String.length(spaces), String.length(rest))
        tokenize(rest_after, acc <> spaces)

      nil ->
        {class, match} = match_rule(rest)
        token_html = render_token(class, match)
        rest_after = String.slice(rest, String.length(match), String.length(rest))
        tokenize(rest_after, acc <> token_html)
    end
  end

  # Try every rule and return the first one that matches.
  # Enum.find_value stops as soon as it gets a result, so rules at the top
  # of @rules are cheaper to reach when they match.
  defp match_rule(text) do
    result = @rules
      |> Enum.find_value(fn {class, regex} ->
        case Regex.run(regex, text) do
          [match | _] -> {class, match}
          nil         -> nil
        end
      end)

    case result do
      # Nothing matched: consume one character as plain text so we don't loop.
      nil      -> {"text", String.slice(text, 0, 1)}
      {c, m}   -> {c, m}
    end
  end

  # Identifiers need an extra step to figure out if they are reserved or a variable.
  defp render_token("identifier", text) do
    real_class = if text in @reserved, do: "reserved-word", else: "variable"
    "<span class=\"#{real_class}\">#{escape(text)}</span>"
  end

  # Functions: render the name and the opening parenthesis as separate spans
  # so both can be styled independently in CSS.
  defp render_token("function", text) do
    "<span class=\"function\">#{escape(text)}</span><span class=\"punctuation\">(</span>"
  end

  defp render_token(class, text) do
    "<span class=\"#{class}\">#{escape(text)}</span>"
  end

  # Escape HTML special characters so the source renders correctly.
  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  # Final HTML wrapper.
  defp build_html(source_path, body) do
    title = Path.basename(source_path)
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>#{title}</title>
        <link rel="stylesheet" href="../token_colors.css">
      </head>
      <body>
        <h1 class="filename">#{title}</h1>
        <pre class="code-block">
    #{body}    </pre>
      </body>
    </html>
    """
  end

end
