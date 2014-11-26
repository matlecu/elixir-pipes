defmodule PipesTest do
  import Should
  use ExUnit.Case

  defmodule Simple do
    use Pipe
    def inc(x), do: x + 1
    def double(x), do: x * 2

    def triple(x, y), do: x * y
    def pipes, do: 1 |> inc |> double
    def with_pipes_identity do
      pipe_with fn(acc, f) -> f.(acc) end,
        [ 1, 2, 3] |> Enum.map( &( &1 - 2 ) ) |> Enum.map( &( &1 * 2 ) )
    end

    def with_pipes_map do
      pipe_with fn(acc, f) -> Enum.map(acc, f) end,
        [ 1, 2, 3] |> inc |> double
    end
  end

  defmodule Matching do
    use Pipe
    def if_test({:ok, _}), do: true
    def if_test(_), do: false
    def inc({code, x}), do: {code, x + 1}
    def double({code, x}), do: {code, x * 2}
    def ok_inc(x), do: {:ok, x + 1}
    def ok_double(x), do: {:ok, x * 2}
    def pipes, do: pipe_matching({:ok, _}, {:ok, 1} |> inc |> double )
    def if_pipes, do: pipe_while(&if_test/1, {:ok, 1} |> inc |> double )
    def pipes_expr, do: pipe_matching(x, {:ok, x}, {:ok, 1} |> ok_inc |> ok_double )
    def if_dopipes, do: pipe_while(&if_test/1, do: {:ok, 1} |> inc |> double )
    def dopipes_expr do
      pipe_matching(x, {:ok, x}) do {:ok, 1} |> ok_inc |> ok_double end
    end
  end

  defmodule Accumulating do
    use Pipe
    def inc(x), do: x + 1
    def double(x), do: x * 2
    def ok_inc(x), do: {:ok, x + 1}
    def ok_double(x), do: {:ok, x * 2}
    def nok_double(x), do: {:nok, x * 2}
    def accumulating_pipes, do: pipe_accumulate(fn(expr, acc) -> [expr|acc] end,
                                                [] |> inc(4) |> 3 |> double(2))
    def accumulate_matching_pipes, do: pipe_accumulate_matching(x, {:ok, x},
                                                       fn(expr, acc) -> [expr|acc] end,
                                                       [] |> ok_inc(4) |> ok_double(2))
    def accumulate_unmatching_pipes, do: pipe_accumulate_matching(x, {:ok, x},
                                                       fn(expr, acc) -> [expr|acc] end,
                                                       [] |> ok_inc(4) |> nok_double(2))
    def accumulate_unmatching_dopipes do
      pipe_accumulate_matching x, {:ok, x}, fn(expr, acc) -> [expr|acc] end do
        [] |> ok_inc(4) |> nok_double(2)
      end
    end
  end

  defmodule Wrapping do
    use Pipe
    def inc(x), do: x + 1
    def double(x), do: x * 2
    def wrapping_pipes, do: pipe_wrapping(&inc/1, 0 |> inc |> double)
    def wrapping_dopipes do
      pipe_wrapping(&inc/1) do
        0 |> inc |> double
      end
    end
  end

  should "compose with identity function" do
    assert [-2, 0, 2] == Simple.with_pipes_identity
  end

  should "compose with map function" do
    assert [4, 6, 8] == Simple.with_pipes_map
  end

  should "pipe correctly" do
    assert  4 == Simple.pipes
  end

  should "pipe matching" do
    assert  {:ok, 4} == Matching.pipes
    assert  {:ok, 4} == Matching.pipes_expr
  end

  should "pipe if" do
    assert  {:ok, 4} == Matching.if_pipes
  end

  should "pipe accumulate" do
    assert [4, 3, 5] == Accumulating.accumulating_pipes
  end

  should "pipe accumulate matching" do
    assert [4, 5] == Accumulating.accumulate_matching_pipes
    assert {:nok, 4} == Accumulating.accumulate_unmatching_pipes
  end

  should "pipe wrapping" do
    assert 5 == Wrapping.wrapping_pipes
  end

  should "pipes work with do notation" do
    assert 5 == Wrapping.wrapping_dopipes
    assert {:nok, 4} == Accumulating.accumulate_unmatching_dopipes
    assert  {:ok, 4} == Matching.dopipes_expr
    assert  {:ok, 4} == Matching.if_dopipes
  end
end
