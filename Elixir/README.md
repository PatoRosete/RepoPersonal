# Elixir Syntax Highlighter – Evidence 2

A lexer written in Elixir that reads Elixir source files, finds the "pieces"
that make up the code (reserved words, numbers, strings, etc.) and produces
one colour-coded HTML file per source file, kind of like how code looks in VS Code.

This evidence extends Evidence 1 by adding support for a full **directory**
of files and a **parallel** version that uses all available CPU cores automatically.

---

## 1. The different things you can find in the code

Elixir has a bunch of different "words" or pieces that mean different things.
This is the expanded list the lexer now recognises:

| Type            | Examples                                                    |
|-----------------|-------------------------------------------------------------|
| Comment         | `# comment`                                                 |
| String          | `"hello"`, `'charlist'`, `"""triple"""`                     |
| Number          | `42`, `3.14`, `0xFF`, `0b1010`, `0o777`, `1_000_000`       |
| Atom            | `:ok`, `:error`, `:"with spaces"`                           |
| Module          | `Enum`, `IO`, `File.Stream`                                 |
| Reserved word   | `def`, `defmodule`, `do`, `end`, `if`, `cond`               |
| Special         | `@moduledoc`, `@spec`, `__MODULE__`                         |
| Sigil           | `~r/regex/`, `~s"string"`, `~w[word list]`                  |
| Capture         | `&String.upcase/1`, `&my_fun/2`, `&1`                       |
| Function        | `foo(`, `is_atom?(`, `my_function(`                         |
| Variable        | `result`, `my_var`, `temperature`                           |
| Ignored var     | `_`, `_head`, `_result`                                     |
| Operator        | `+`, `-`, `*`, `/`, `==`, `|>`, `->`, `&&`                  |
| Punctuation     | `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `.`                 |

---

## 2. How each thing is identified (with regex)

Every type of piece has its own regex. All of them start with `\A` to force
the match to happen right at the beginning of whatever is left to read. The
lexer tries the rules one by one in order and keeps the first one that hits.

| Type            | Regex                                                                          |
|-----------------|--------------------------------------------------------------------------------|
| Triple string   | `\A"{3}[\s\S]*?"{3}`                                                           |
| Comment         | `\A#.*`                                                                        |
| Sigil           | `\A~[a-zA-Z](?:[\/\|"'…])(?:[^\\]\|\\.)* ?(?:[\/\|"'…])[a-z]*`              |
| String `"`      | `\A"(?:[^"\\]\|\\.)*"`                                                         |
| String `'`      | `\A'(?:[^'\\]\|\\.)*'`                                                         |
| Number (hex)    | `\A0x[0-9a-fA-F][0-9a-fA-F_]*`                                                |
| Number (float)  | `\A\d[\d_]*\.\d[\d_]*`                                                         |
| Number (int)    | `\A\d[\d_]*`                                                                   |
| Atom            | `\A:[a-zA-Z_]\w*[?!]?` and `\A:"(?:[^"\\]\|\\.)*"`                            |
| Module          | `\A[A-Z][a-zA-Z0-9_]*(?:\.[A-Z][a-zA-Z0-9_]*)*`                               |
| Special         | `\A@[a-zA-Z_]\w*` and `\A__[A-Z_]+__`                                         |
| Capture         | `\A&[a-z_]\w*\/\d+` and `\A&\d+`                                              |
| Ignored var     | `\A_\w*`                                                                       |
| Function        | `\A[a-z_]\w*[?!]?(?=\()` (lookahead for `(`)                                  |
| Identifier      | `\A[a-zA-Z_]\w*[?!]?` (then checked against the reserved list)               |
| Operator        | `\A(?:\|>|->|<-|<>|>=|<=|==|!=|=~|&&|\|\||…)` (longest first)               |
| Punctuation     | `\A[\(\)\[\]\{\},%;\.\|:]`                                                     |

**The order matters a lot.** Triple-quoted strings go first so they are not
broken into three separate tokens. Comments go early so the `#` symbol is
never confused with punctuation. Two-character operators like `>=` or `|>`
go before the one-character ones so the longer match wins. The function rule
uses a zero-width lookahead (`(?=\()`) so the parenthesis stays on the input
and is picked up by the punctuation rule on the very next step.

When a word matches the identifier rule, we check if it's in Elixir's list
of reserved words. If it is, it gets painted as reserved; if not, it's
treated as a regular variable.

---

## 3. How to run

Open `iex` and load both files:

```bash
iex
```

```elixir
c "highlighter_sequential.ex"
c "highlighter_parallel.ex"
```

### Sequential – process every file in a directory one by one

```elixir
TecLexer.Sequential.run("source_files")
```

HTML files land in `output_sequential/` as `<filename>_sequential.html`.

### Parallel – process every file using all CPU cores

```elixir
TecLexer.Parallel.run("source_files")
```

HTML files land in `output_parallel/` as `<filename>_parallel.html`.

You can also pass a custom output directory as the second argument:

```elixir
TecLexer.Sequential.run("my_dir", "my_output")
TecLexer.Parallel.run("my_dir", "my_output")
```

---

## 4. How it works and how fast it is

### The idea of the algorithm

The lexer eats the text from left to right. At each position it tries the
rules in order, keeps the first one that matches, wraps the matched piece in
a `<span>` with the right CSS class, and keeps going with whatever is left.
It repeats until the line is empty. Files are read with `File.stream!/1` so
only one line lives in memory at a time, no matter how large the file is.

### Variables for the analysis

| Symbol | Meaning |
|--------|---------|
| `n`    | total characters in the input |
| `r`    | number of rules in `@rules` (25, a constant) |
| `L`    | average token length |

### How much work per line

For a line with `m` characters:

- The tokenizer gets called once per token, so about `m / L` times.
- Each time it tries the rules with `Enum.find_value`, which stops at the
  first hit – so on average fewer than `r` attempts are made.
- Since the regexes are anchored with `\A`, each attempt only looks at the
  start of the remaining string, not the whole thing.

Work per line: **O((m / L) · r · L) = O(m · r)**.

### Total

Adding up all the lines: **O(n · r)**.

Since `r` is a small constant (25), in practice this is **O(n)** — linear
in the size of the file. Each character in the input is looked at a fixed
number of times.

### The parallel version

The parallel version does exactly the same work per file. The difference is
that `Task.async_stream` creates one lightweight Elixir process per file and
the BEAM VM scheduler spreads them across all available CPU cores:

```elixir
|> Task.async_stream(fn name -> highlight_file(...) end,
     max_concurrency: System.schedulers_online(),
     timeout: :infinity)
```

No manual thread count is needed. The runtime decides how many tasks run
at the same time based on the machine. If the machine has 8 cores and there
are 20 files, up to 8 files are highlighted at the same time.

The wall-clock time drops roughly by the number of available cores when
files are roughly the same size. In practice, disk I/O and BEAM overhead
reduce the gain a little.

### Execution time measurements

Both versions were run 4 times on the same directory. The first run of each
is treated as warm-up and excluded from the average (file-system cache and
BEAM scheduler are cold on the first call).

Machine: Windows 11, Erlang/OTP 27 [smp:16:16], Elixir 1.17.3

| Run | Sequential  | Parallel    |
|-----|-------------|-------------|
| 1   | 0.458583 s  | 0.210246 s  |
| 2   | 0.372256 s  | 0.099914 s  |
| 3   | 0.327585 s  | 0.098356 s  |
| 4   | 0.331263 s  | 0.092848 s  |
| **Avg (runs 2–4)** | **0.343701 s** | **0.097039 s** |

**Speedup: 0.343701 / 0.097039 ≈ 3.54x**

The machine has 16 logical cores. The speedup of ~3.5x is lower than the
theoretical 16x ceiling because the workload is partly I/O-bound (all tasks
read from the same disk) and because file sizes are unequal so some tasks
finish much earlier than others.

---

## 5. Report and reflection

### Findings

The analysis confirms that the lexer is **O(n)** – linear in the size of the
input. This holds for both versions: parallelism changes *which CPU* does
the work, not *how much* work there is per character.

The main factors that affect the hidden constant are:

- **Rule ordering** – putting frequent tokens (comments, strings, numbers)
  near the top of `@rules` means fewer regex attempts per token on average.
- **`Enum.find_value` instead of `Enum.filter`** – short-circuits on the
  first match instead of running every rule.
- **`File.stream!/1`** – only one line is in memory at a time, so even very
  large files don't cause memory problems.

The parallel version is faster on machines with multiple cores because files
are independent of each other: highlighting file A does not need any result
from file B, so there is no waiting between tasks.

### Ethical reflection

A lexer is the first piece of any compiler or interpreter, and tools like
this one are behind almost all the software we use: programming languages,
search engines, syntax checkers, IDEs like VS Code, code review systems.
They are invisible but they are everywhere.

Programming languages carry views of the world and biases with them. A tool
that only understands popular languages makes code written in less well-known
languages count for less, and reinforces the idea that only a handful of
languages are "serious." Building lexers is not just a technical exercise;
it is also a chance to think about which code gets recognised as real code
and which code gets ignored.

Finally, automated code analysis is being used more and more to train AI
models: Copilot, autocomplete tools, code generators. Precisely because code
can be split into clean, ordered tokens, it is easy to scrape it, throw it
in a database, and train models without asking the person who wrote it.
Anyone building this kind of tool has some responsibility to think about how
their work is going to be used down the line.