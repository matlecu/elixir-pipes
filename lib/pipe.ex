defmodule Pipe do
  @moduledoc """
  def inc(x), do: x + 1
  def double(x), do: x * 2

  1 |> inc |> double
  """
  defmacro __using__(_) do
    quote do
      import Pipe
    end
  end

  #     pipe_matching { :ok, _ }, x,
  #        ensure_protocol(protocol)
  #     |> change_debug_info(types)
  #     |> compile

  defmacro pipe_matching(test, pipes) do
    merge_fun = matching_merge((quote do: expr), (quote do: unquote(test) = expr))
    reduce_pipe(&reduce_piped/4, merge_fun, nil, pipes)
  end

  defmacro pipe_matching(expr, test, wrapper_fun \\ nil, pipes) do
    reduce_pipe(&reduce_piped/4, matching_merge(expr, test), wrapper_fun, pipes)
  end

  defp matching_merge(expr, matching) do
    quote do
      fn (acc, segment_fun) ->
        case acc do
          unquote(matching) -> segment_fun.(unquote(expr))
          acc -> acc
        end
      end
    end
  end

  #     pipe_while &(valid? &1),
  #     json_doc |> transform |> transform

  defmacro pipe_while(test, wrapper_fun \\ nil, pipes) do
    reduce_pipe(&reduce_piped/4, if_merge(test), wrapper_fun, pipes)
  end

  defp if_merge(test) do
    quote do
      fn (acc, segment_fun) ->
        case unquote(test).(acc) do
          true  -> segment_fun.(acc)
          false -> acc
        end
      end
    end
  end

  # each function of the pipe is wrapped by the wrapping_fun.
  # The accumulated value is still passed as first argument
  # fo the original segment.

  defmacro pipe_wrapping(wrapper_fun, pipes) do
    reduce_pipe(&reduce_piped/4, wrapping_merge(wrapper_fun), nil, pipes)
  end

  defp wrapping_merge(wrapper_fun) do
    quote do
      fn (acc, segment_fun) -> unquote(wrapper_fun).(segment_fun.(acc)) end
    end
  end

  #     pipe_accumulate merge_fun,
  #     initial value |> value to merge |> next value to merge

  defmacro pipe_accumulate(merge_fun, wrapper_fun \\ nil, pipes) do
    reduce_pipe(&reduce_unpiped/4, accumulate_merge(merge_fun), wrapper_fun, pipes)
  end

  defp accumulate_merge(merge_fun) do
    quote do
      fn (acc, segment_fun) -> unquote(merge_fun).(segment_fun.(), acc) end
    end
  end

  #     pipe_accumulate_matching expr, test, merge_fun,
  #     initial value |> value to merge if match |> next value to merge if match

  defmacro pipe_accumulate_matching(test, merge_fun, pipes) do
    merge_fun = accumulate_matching_merge((quote do: expr),
                                          (quote do: unquote(test) = expr),
                                          merge_fun)
    reduce_pipe(&reduce_unpiped/4, merge_fun, nil, pipes)
  end

  defmacro pipe_accumulate_matching(expr, test, merge_fun, wrapper_fun \\ nil, pipes) do
    reduce_pipe(&reduce_unpiped/4, accumulate_matching_merge(expr, test, merge_fun),
                wrapper_fun, pipes)
  end

  defp accumulate_matching_merge(expr, test, merge_fun) do
    quote do
      fn (acc, segment_fun) ->
        case segment_fun.() do
          unquote(test) -> unquote(merge_fun).(unquote(expr), acc)
          non_match -> non_match
        end
      end
    end
  end

  # a custom merge function that takes the piped function and an argument,
  # and returns the accumulated value
  # pipe_with fn(f, acc) -> Enum.map(acc, f) end,
  #   [ 1, 2, 3] |> &(&1 + 1) |> &(&1 * 2)

  defmacro pipe_with(fun, wrapper_fun \\ nil, pipes) do
    reduce_pipe(&reduce_piped/4, fun, wrapper_fun, pipes)
  end

  # the generic reduce system to implement all elixir pipes
  # can reduce the piped functions, or just the segments of th pipe
  # without piping the first argument in

  defp reduce_pipe(reduce_fun, merge_fun, wrapper_fun, pipes) do
    # add support for do notation for pipes
    pipes = case pipes do
      [do: pipes] -> pipes
      pipes -> pipes
    end
    [{h,_}|t] = Macro.unpipe(pipes)
    Enum.reduce t, h, &(reduce_fun.(&1, &2, merge_fun, wrapper_fun))
  end

  defp reduce_piped({segment, pos}, acc, with_fun, wrapper_fun) do
    pipe = Macro.pipe((quote do: x), segment, pos)
    if wrapper_fun do
      quote do
        unquote(with_fun).(unquote(acc),
                           fn(x) -> unquote(wrapper_fun).(unquote(pipe)) end)
      end
    else
      quote do unquote(with_fun).(unquote(acc), fn(x) -> unquote(pipe) end) end
    end
  end

  defp reduce_unpiped({segment, _pos}, acc, with_fun, wrapper_fun) do
    if wrapper_fun do
      quote do
        unquote(with_fun).(unquote(acc),
                           fn() -> unquote(wrapper_fun).(unquote(segment)) end)
      end
    else
      quote do unquote(with_fun).(unquote(acc), fn() -> unquote(segment) end) end
    end
  end
end
