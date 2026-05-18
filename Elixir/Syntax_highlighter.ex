# Syntax highlighter
#
# Carlos Enrique Rosete Pascual
# 17/05/2026
#

defmodule TecLexer do

  # here ypu can define the documents to be processed and the output file name
  @input_file  "ariel_set_1_test.exs"
  @output_file "Final.html"

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
    # Single-line comment: from # until end of line
    {"comment",     ~r/\A#.*/},

    # Strings with double quotes (allows escaped quotes inside: \")
    {"string",      ~r/\A"(?:[^"\\]|\\.)*"/},

    # Charlists with single quotes
    {"string",      ~r/\A'(?:[^'\\]|\\.)*'/},

    # Numbers: integers and floats
    {"number",      ~r/\A\d[\d_]*(?:\.\d[\d_]*)?/},

    # Atoms: :name or :"quoted name"
    {"atom",        ~r/\A:[a-zA-Z_][a-zA-Z   0-9_?!]*/},
    {"atom",        ~r/\A:"(?:[^"\\]|\\.)*"/},

    # Module names: start uppercase, may chain with dots (Enum, IO, File.Stream)
    {"module",      ~r/\A[A-Z][a-zA-Z0-9_]*(?:\.[A-Z][a-zA-Z0-9_]*)*/},

    # Module attributes (@reserved, @moduledoc) and __MODULE__ etc.
    {"special",     ~r/\A@[a-zA-Z_][a-zA-Z0-9_]*/},
    {"special",     ~r/\A__[A-Z]+__/},

    # Identifier: variables, function names, and reserved words.
    # We decide which one it really is in classify_identifier/1.
    {"identifier",  ~r/\A[a-zA-Z_][a-zA-Z0-9_]*[?!]?/},

    # Operators (longest first so >= matches before >)
    {"operator",    ~r/\A(?:\|>|->|<-|<>|>=|<=|==|!=|=~|&&|\|\||::|\.\.|=|\+|\-|\*|\/|<|>|!|&)/},

    # Punctuation: parens, brackets, braces, comma, semicolon, dot, pipe, colon
    {"punctuation", ~r/\A[\(\)\[\]\{\},;\.\|:]/}
  ]

  # Public entry point.
  def convert() do
    # Read the file line by line, convert each one to HTML, and join.
    # Same style as the prof example stream -> map -> join.
    body = @input_file
      |> File.stream!()
      |> Enum.map(&line_to_html/1)
      |> Enum.join("")

    # Wrap everything in the HTML template and write.
    html = build_html(body)
    File.write(@output_file, html)
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

  # Try every rule, keep only the ones that matched, and take the first one.
  # Enum.filter is used here to throw away rules that returned nil

  defp match_rule(text) do
    matches = @rules
      |> Enum.map(fn {class, regex} ->
        case Regex.run(regex, text) do
          [match | _] -> {class, match}
          nil -> nil
        end
      end)
      |> Enum.filter(fn result -> result end)
      # |> IO.inspect(label: "matches") # IO.inspect in case we want to debbug the matching process

    case matches do
      # First rule in the list that matched wins (order matters in @rules).
      [first | _] -> first
      # Nothing matched: consume one character as plain text so we don't loop.
      [] -> {"text", String.slice(text, 0, 1)}
    end
  end


  # Identifiers need an extra step it is to figure out if it's reserved or a variable.
  defp render_token("identifier", text) do
    real_class = classify_identifier(text)
    "<span class=\"#{real_class}\">#{escape(text)}</span>"
  end

  defp render_token(class, text) do
    "<span class=\"#{class}\">#{escape(text)}</span>"
  end

  # Decide what an identifier really is:
  # if it's in the reserved list -> "reserved-word"
  # otherwise -> "variable"
  defp classify_identifier(text) do
    if text in @reserved do
      "reserved-word"
    else
      "variable"
    end
  end

  # Escape HTML special characters so the source renders correctly this is a little AI help
  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  # Final HTML wrapper.
  # I can not found a correct way to put the date and hour so i skipped it :(
  defp build_html(body) do
    """
    <!DOCTYPE html>
    <html>
      <head>
        <title>#{@input_file}</title>
        <link rel="stylesheet" href="token_colors.css">
      </head>
      <body>
        <pre>
    #{body}    </pre>
      </body>
    </html>
    """
  end

end
