defmodule Credo.Check.IronLaw.NoFloatForMoney do
  @moduledoc """
  Iron Law #4: NEVER use `:float` for money — use `:decimal` or `:integer`.

  Matches Ecto schema fields and migration additions where the field name is
  money-related (price, amount, cost, balance, fee, rate, etc.) but type is
  `:float`.

  ## Examples (non-compliant)

      defmodule Payments do
        use Ecto.Schema

        field :price, :float           # ❌ money field with :float
        field :cost, :float            # ❌ money field with :float
        field :width, :float           # OK — not money-related
        field :price, :decimal         # OK — proper type
      end

  ## Configuring in `.credo.exs`

      %{
        checks: [
          %Credo.Check.Config{
            check: Credo.Check.IronLaw.NoFloatForMoney,
            meta: [money_keywords: ~w(price amount cost balance fee rate total)]
          }
        ]
      }
  """

  use Credo.Check, [category: :design,
    exit_status: 2]

  @default_money_kw ~w(price amount cost balance total fee rate salary wage payment
                       credit debit revenue discount tax tip refund commission bonus
                       penalty fine reward earnings profit loss currency money cash
                       bill invoice subscription shipment delivery insurance premium
                       donation charge tip_amount subtotal grand_total)

  @impl true
  def run(%SourceFile{} = source_file, params) do
    money_kw = get_in(params, [:money_keywords]) || @default_money_kw
    money_re = Regex.compile!("(?i)(#{join(money_kw, "|")})")

    Map.get(source_file, :ast)
    |> traverse_call(&issue_for_call(&1, money_re, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp issue_for_call({:field, meta, [name, type | _rest]}, money_re, source_file)
       when is_atom(name) do
    field_name = Atom.to_string(name)

    case type do
      {:atom, _, :decimal} -> nil
      {:atom, _, :integer} -> nil
      {:atom, _, :float} ->
        if String.match?(field_name, money_re) do
          issue(source_file, field_name, meta[:line] || 0)
        else
          nil
        end
      _ -> nil
    end
  end

  defp issue_for_call({:add, meta, [name, type | _rest]}, money_re, source_file)
       when is_atom(name) do
    field_name = Atom.to_string(name)

    case type do
      {:atom, _, :decimal} -> nil
      {:atom, _, :integer} -> nil
      {:atom, _, :float} ->
        if String.match?(field_name, money_re) do
          issue(source_file, field_name, meta[:line] || 0)
        else
          nil
        end
      _ -> nil
    end
  end

  defp issue_for_call(_ast, _re, _source_file), do: nil

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:field, _, [_ | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(call = {:add, _, [_ | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, field_name, line) do
    %Issue{
      filename: source_file.filename,
      line_no: line,
      message: """
      Field "#{field_name}" appears to be money-related but uses :float.
      Use :decimal or :integer (cents). See Iron Law #4.\n\n" <>
      "  field :#{field_name}, :decimal      # For exact decimals\n" <>
      "  field :#{field_name}, :integer       # For smallest currency units\n"
    """
    }
  end

  defp join([], _), do: ""
  defp join(keywords, _), do: Enum.map_join(keywords, &Atom.to_string/1, "|")
end