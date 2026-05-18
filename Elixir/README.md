# Elixir Lexer

A lexer written in Elixir that reads Elixir source files, finds the "pieces"
that make up the code (reserved words, numbers, strings, etc.) and spits out
an HTML file painted with colors, kind of like how code looks in VS Code.

In this project, the language being analyzed and the language the lexer is
written in are both **Elixir**.

I chose Elixir because it's a language I like and I wanted to get more practice with it. It's also a good fit for this kind of task and i hope i get that extra point. I also work a lot with one of my mates in the class so we help a little bit with each other, but we write our own code and do our own analysis.

---

## 1. The different things you can find in the code

Elixir has a bunch of different "words" or pieces that mean different things.
This is the list the lexer recognizes, taken from the
[official syntax reference](https://hexdocs.pm/elixir/syntax-reference.html):

| Type            | Examples                                       |
|-----------------|------------------------------------------------|
| Comment         | `# comment`                          |
| String          | `"hello"`, `'charlist'`                        |
| Number          | `42`, `3.14`, `1_000_000`                      |
| Atom            | `:ok`, `:error`, `:"with spaces"`              |
| Module          | `Enum`, `IO`, `File.Stream`                    |
| Reserved word   | `def`, `defmodule`, `do`, `end`, `if`, `cond`  |
| Special         | `@moduledoc`, `@reserved`, `__MODULE__`        |
| Variable        | `tem`, `result`, `my_var`                      |
| Operator        | `+`, `-`, `*`, `/`, `==`, `|>`, `->`, `&&`     |
| Punctuation     | `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `.`    |



---

## 2. How each thing is identified (with regex)

Every type of piece has its own regex. All of them start with `\A` to force
the match to happen right at the beginning of whatever is left to read. The
lexer tries the rules one by one in order and keeps the first one that hits.

| Type            | Regex                                                                    |
|-----------------|--------------------------------------------------------------------------|
| Comment         | `\A#.*`                                                                  |
| String with `"` | `\A"(?:[^"\\]|\\.)*"`                                                    |
| String with `'` | `\A'(?:[^'\\]|\\.)*'`                                                    |
| Number          | `\A\d[\d_]*(?:\.\d[\d_]*)?`                                              |
| Atom            | `\A:[a-zA-Z_][a-zA-Z0-9_?!]*` and `\A:"(?:[^"\\]|\\.)*"`                  |
| Module          | `\A[A-Z][a-zA-Z0-9_]*(?:\.[A-Z][a-zA-Z0-9_]*)*`                          |
| Special         | `\A@[a-zA-Z_][a-zA-Z0-9_]*` and `\A__[A-Z]+__`                           |
| Identifier      | `\A[a-zA-Z_][a-zA-Z0-9_]*[?!]?` (later decided to be reserved or variable) |
| Operator        | `\A(?:\|>|->|<-|<>|>=|<=|==|!=|=~|&&|\|\||::|\.\.|=|\+|\-|\*|\/|<|>|!|&)`|
| Punctuation     | `\A[\(\)\[\]\{\},;\.\|:]`                                                |

**The order matters a lot.** Comments go first because otherwise the `#`
symbol would get mixed up with punctuation. Strings also go early, so that
if there's a `+` or an `if` inside a string, they don't get confused with
an operator or a reserved word. Two-character operators like `>=` or `|>`
go before the one-character ones (`>` or `|`) so the longer one hits first.

When a word matches the identifier rule, we check if it's in Elixir's list
of reserved words. If it is, it gets painted as reserved; if not, it's
treated as a regular variable.

---

## 3. How it works and how fast it is

### The idea of the algorithm

The lexer eats the text from left to right. At each position it tries the
rules in order, keeps the first one that matches, keeps that piece of
the string, wraps it in a `<span>` with the right class, and keeps going
with whatever is left. It repeats until it runs out of line.

### Variables for the analysis

- `n` = how many characters the file has in total.
- `r` = how many rules are in `@rules` (11 in this case, a constant).
- `L` = how long a token is on average.

### How much work per line

For a line with `m` characters:

- The tokenizer gets called once per piece, so `m / L` times.
- Each time it tries the `r` rules with `Enum.map` and filters out the
  ones that didn't hit with `Enum.filter`. That's linear in `r`.
- Since the regexes are anchored with `\A`, how long they take to run
  depends on the size of the token they produce, not on the rest of
  the line.

Work per line: **O((m / L) · r · L) = O(m · r)**.

### Total

Adding up all the lines: **O(n · r)**.

Since `r` is a small constant (11), in practice this is **O(n)**, meaning
linear in the size of the file. It makes sense: each character in the
input gets looked at a fixed number of times.

### What you actually see

Running the lexer on that ariel text (around 520 lines) finishes in way
less than a second. If you double the file, the time roughly doubles too,
which is exactly what the analysis predicts.

---

## 4. Report and reflection

### Findings

The analysis confirms that the lexer grows linearly with the size of the
file. What affects the "hidden constant" the most is how many rules there
are and how expensive the regexes are.

Reading the file with `File.stream!/1` instead of loading the whole thing
into memory also helps: even if the file were huge, you only work with
one line at a time. Plus it's the natural way to do it in Elixir.

### Ethical reflection

A lexer is the first piece of any compiler or interpreter, and tools like
this one are behind almost all the software we use: programming languages,
search engines, syntax checkers, IDEs like VS Code, code review systems.
They're invisible but they're everywhere.

Programming languages carry views of
the world and biases with them. A tool that only understands popular
languages makes code written in less well-known languages count for less,
and reinforces the idea that only a handful of languages are "serious."
Building lexers isn't just a technical exercise; it's also a chance to
think about which code gets recognized as real code and which code gets
ignored.

Finally, automated code analysis is being used more and more to train AI
models: Copilot, autocomplete tools, code generators. Precisely because
code can be split into clean, ordered tokens, it's really easy to scrape
it, throw it in a database, and train models without asking the person
who wrote it. Anyone building this kind of tool has some responsibility
to think about how their work is going to be used down the line.