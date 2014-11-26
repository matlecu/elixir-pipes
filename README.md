# elixir-pipes

Elixir Pipes is an [Elixir](https://github.com/elixir-lang/elixir/) extension that extends the pipe (|>) operator through macros.

## The Pipe: Elixir Flavor Packet

Some of the [best](http://joearms.github.io/2013/05/31/a-week-with-elixir.html) [programmers](http://pragprog.com/book/elixir/programming-elixir) who have taken an early dive into Elixir have mentioned the pipe as one of the key features of the language. It allows a clear, concise expression of the programmer's intent:

```elixir
  def inc(x), do: x + 1
  def double(x), do: x * 2
  
  1 |> inc |> double
```

The return value of each function is used as the first argument of the next function in the pipe. It's a beautiful expression that makes the intent of the programmer clear.

### Trouble in the Kitchen

Sometimes, you need to compose functions with a different strategy. Say your functions use Erlang-style APIs. You might have functions that return `{:ok, value}` or `{:error, value}`. Then, the pipe operator might make things difficult. After you receive an `error` code, you probably want the pipe to stop.

Elixir-Pipes allows you to specify a strategy, in one concise space, that you can then apply to all segments in an Elixir pipe. This capibility will help you compose many different types of functions. How many times have you wanted to:

- compose a pipe that uses some variation of a function call like  `[1, 2, 3] |> add(1) |> times(2)` ?
- halt the execution of a pipe on error?
- tease nils to empty strings, without changing your original funcions?
- transform exceptions to Erlang-style `{:error, x}` tuples?

The recipes are all there waiting for you.

## Getting Started

All you need to do to get started is to add the project to your mix file as a dependency. Then, when you want to use the macros, you'll simply use it:

```Elixir
use Pipe

...
```

That's it. After that, you can continue to use unadorned pipes, or use one of the prepackaged compositions. Initially, we have three:

### pipe_matching

This function will compose as long as the computed value matches the value so far. For example, consider this Russian Roulette application:

```elixir
defmodule RussianRoulette do
  def click(acc) do
    IO.puts "click..."
    {:ok, "click"}
  end

  def bang(acc) do
    IO.puts "BANG."
    {:error, "bang"}
  end
end

pipe_matching {:ok, _},
{:ok, ""} |> click |> click |> bang |> click

```

...would produce...

```
click...
click...
BANG.
```

It would evaluate functions as long as the accumulator matched the expression. In this case, we process statements as long as the composition yields an `:ok` on the left hand side.

### pipe_accumulate and pipe_accumulate_matching
This function will execute the functions of the pipe without passing any new
argument, and merge each result with the merging function.
The pipe_accumulate_matching will keep doing this as long as the expression
matches, the same way as pipe_matching.
The first value can be seen as the initialization of the merge data structure.

As an example, imagine you want to make a few API calls, and merge result while
the call are successful, but return the error as soon as one fails:

```
pipe_accumulate_matching x, {:ok, x}, &Map.merge/2,
  %{} |> API.get_user_data(123) |> API.get_avatar(123)
```

### pipe_while

Sometimes, you may want to test on something other than a match. This composition strategy will continue as long as your composition satisfies the test function you provide. To implement the above, you could do this just as well:

```elixir
    def while_test({:ok, _}), do: true
    def while_test(_), do: false
    def inc({code, x}), do: {code, x + 1}
    def double({code, x}), do: {code, x * 2}

    pipe_while(&while_test/1, {:ok, ""} |> click |> click |> bang |> click )
```

You could also write tests for testing a value, such as whether a value is even, whether a record is valid, or whether a user is authorized.

### pipe_with

Sometimes, you want to write the composition rules yourself. You can do this with `pipe_with function, pipe` where function has a sig of `f(x, pipe_segment)` where `pipe_segment` is a function in the pipe. The macro will pass the accumulated value and a function that wraps each pipe segment to your function.

Say you have a list, and you want to do arithmetic on each element of the list. You can do so with `pipe_with` like this:

```elixir
  def inc(x), do: x + 1
  def double(x), do: x * 2

  pipe_with fn(acc, f) -> Enum.map(acc, f) end,
        [ 1, 2, 3] |> inc |> double

```
This returns

```
[(1 + 1) * 2, (2 + 1) * 2, (2 + 2) * 2]
```
or 
```
[4, 6, 8]
```

You could also wrap exceptions, and translate them to the form `{:error, acc}`, or change nils to blank strings or empty arrays.

Contributions are welcome. Just send a pull request (you must have tests). 

