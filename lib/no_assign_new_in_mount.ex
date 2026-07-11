defmodule Credo.Check.IronLaw.NoAssignNewInMount do
  @moduledoc """
  Iron Law #21: NEVER use `assign_new` for values refreshed every mount.

  `assign_new/3` skips the function if the key already exists. In `mount/3`
  which runs on every page load, this means stale values persist across
  requests. Use `assign/3` for values that must be refreshed on every mount.

  ## Examples (non-compliant)

      def mount(_params, _session, socket) do
        socket
        |> assign_new(:locale, fn -> get_locale() end)  # ❌ stale on revisit
        |> assign_new(:current_user, fn -> load_user(socket) end)  # ❌ stale

  ## Examples (compliant)

      def mount(_params, _session, socket) do
        socket
        |> assign(:locale, get_locale())  # ✅ always refresh
        |> assign(:current_user, load_user(socket))  # ✅ always refresh
  """

  use Credo.Check, [category: :consistency,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    unless String.ends_with?(source_file.filename, "_live.ex") do
      []
    end

    Map.get(source_file, :ast)
    |> traverse_call(&check_assign_new_in_mount(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_assign_new_in_mount({:def, meta, [{:mount, _, [_params, _session, _socket]} | body]} = _call, source_file) do
    case find_assign_new(body) do
      nil -> nil
      {key, line} -> issue(source_file, key, line || meta[:line] || 0)
    end
  end

  defp check_assign_new_in_mount(_, _), do: nil

  defp find_assign_new(body) do
    body
    |> flatten()
    |> Enum.find_value(fn
      {:assign_new, meta, [key, _]} -> {key, meta[:line]}
      {:., _, [{:., _, [{:., _, [:Phoenix, :LiveView]}, :Socket]}, :assign_new]} -> {:unknown, nil}
      _ -> nil
    end)
  end

  defp flatten({_, _, children}) when is_list(children) do
    Enum.flat_map(children, &flatten/1)
  end

  defp flatten(node) do
    [node]
  end

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:def, _, [{:mount, _, [_]} | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, key, line) do
    key_str = case key do
      {:atom, _, name} -> to_string(name)
      name when is_atom(name) -> to_string(name)
      _ -> "key"
    end

    %Issue{
      filename: source_file.filename,
      line_no: line,
      message: """
      assign_new(:#{key_str}) in mount — value won't refresh on subsequent visits.\n" <>
      "assign_new/3 skips if the key exists, causing stale data. Use assign/3\n" <>
      "for values that must update every mount (locale, current_user, etc.).\n\n" <>
      "  assign(socket, :#{key_str}, get_#{key_str}())\n"
    """
    }
  end
end