defmodule Credo.Check.Extra.NoFloatForMoney do
  @moduledoc """
  Extra Rule #4: NEVER use `:float` for money — use `:decimal` or `:integer`.

  Matches Ecto schema fields and migration additions where the field name is
  money-related (price, amount, cost, balance, fee, rate, etc.) but type is
  `:float`.

  ## Examples (non-compliant)

      defmodule Payments do
        use Ecto.Schema

        field :price, :float           # [cross] money field with :float
        field :cost, :float            # [cross] money field with :float
        field :width, :float           # OK — not money-related
        field :price, :decimal         # OK — proper type
      end

  ## Configuring in `.credo.exs`

      %{
        checks: [
          %Credo.Check.Config{
            check: Credo.Check.Extra.NoFloatForMoney,
            meta: [money_keywords: ~w(price amount cost balance fee rate total)]
          }
        ]
      }
  """

  use Credo.Check,
    category: :design,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @default_money_kw ~w(price amount cost balance total fee rate salary wage payment
                       credit debit revenue discount tax tip refund commission bonus
                       penalty fine reward earnings profit loss currency money cash
                       bill invoice subscription shipment delivery insurance premium
                       donation charge tip_amount subtotal grand_total)

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, params) do
    money_kw = Keyword.get(params, :money_keywords, @default_money_kw)
    money_re = Regex.compile!("(?i)(#{join(money_kw, "|")})")

    ASTTraversal.collect_issues(source_file, fn ast, source_file ->
      issue_for_call(ast, money_re, source_file)
    end)
  end

  defp issue_for_call({:field, meta, [name, type | _rest]}, money_re, source_file)
       when is_atom(name) do
    check_field_type(type, Atom.to_string(name), money_re, source_file, meta[:line] || 0)
  end

  defp issue_for_call({:add, meta, [name, type | _rest]}, money_re, source_file)
       when is_atom(name) do
    check_field_type(type, Atom.to_string(name), money_re, source_file, meta[:line] || 0)
  end

  defp issue_for_call(_ast, _re, _source_file), do: nil

  defp check_field_type(type, field_name, money_re, source_file, line) do
    if float?(type) and String.match?(field_name, money_re) do
      issue(source_file, field_name, line)
    else
      nil
    end
  end

  defp float?(:float), do: true
  defp float?(_), do: false

  defp issue(source_file, field_name, line) do
    %Issue{
      filename: source_file.filename,
      line_no: line,
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :design,
      message:
        "Field \"#{field_name}\" appears to be money-related but uses :float. Use :decimal or :integer (cents)."
    }
  end

  defp join(keywords, sep), do: Enum.map_join(keywords, sep, &to_string/1)
end
