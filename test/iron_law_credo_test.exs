defmodule IronLawCredoTest do
  use ExUnit.Case

  test "returns all check modules" do
    checks = IronLawCredo.checks()
    assert is_list(checks)
    assert length(checks) == 12
    assert Credo.Check.IronLaw.NoFloatForMoney in checks
    assert Credo.Check.IronLaw.StringToAtom in checks
  end
end

defmodule NoAssignNewInMountTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoAssignNewInMount

  test "detects assign_new in mount" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign_new(:locale, fn -> "en" end)
        |> assign(:other, "value")
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("assign_new") end)
  end

  test "does not flag plain assign in mount" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign(:locale, "en")
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips non-live files" do
    source = """
    defmodule MyController do
      def index(conn, _params) do
        conn |> put_session(:key, "value")
      end
    end
    """

    source
    |> to_source_file("my_controller.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoAuthInHandleEventTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoAuthInHandleEvent

  test "detects handle_event without auth" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        {:noreply, socket}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("authorization") end)
  end

  test "does not flag handle_event with auth check" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        if authorized?(socket.assigns.user) do
          {:noreply, socket}
        end
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoBareChangesetErrorTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoBareChangesetError

  test "detects bare {:error, _} in handle_event" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.update(params) do
          {:ok, result} -> {:noreply, socket}
          {:error, _} -> {:noreply, socket}
        end
      end
    end
    """

    source
|> to_source_file("my_liveview_live.ex")
|> run_check(@check)
|> assert_issue(fn issue -> assert issue.message |> String.contains?("changeset") end)
  end
end

defmodule NoFloatForMoneyTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoFloatForMoney

  test "detects :float for money field" do
    source = """
    defmodule Product do
      use Ecto.Schema

      field :price, :float
    end
    """

    source
    |> to_source_file("product.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?(":float") end)
  end

  test "does not flag :decimal for money field" do
    source = """
    defmodule Product do
      use Ecto.Schema

      field :price, :decimal
    end
    """

    source
    |> to_source_file("product.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag :float for non-money field" do
    source = """
    defmodule Geometry do
      use Ecto.Schema

      field :width, :float
    end
    """

    source
    |> to_source_file("geometry.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoImplicitCrossJoinTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoImplicitCrossJoin

  test "detects implicit cross join" do
    source = """
    defmodule Query do
      def query do
        from(a in Account, b in Booking)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("cross join") end)
  end

  test "does not flag explicit join" do
    source = """
    defmodule Query do
      def query do
        from(a in Account, join: b in assoc(a, :bookings), on: true)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoPubsubWithoutConnectedTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoPubsubWithoutConnected

  test "detects subscribe without connected? guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("connected?") end)
  end

  test "does not flag subscribe with connected? guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        end
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoRawUntrustedTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoRawUntrusted

  test "detects raw with variable" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(@user_bio)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("XSS") end)
  end

  test "does not flag raw with hardcoded string" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw("<p>Static content</p>")
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule StringToAtomTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.StringToAtom

  test "detects String.to_atom with variable" do
    source = """
    defmodule MyModule do
      def convert(input) do
        String.to_atom(input)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("to_existing_atom") end)
  end

  test "does not flag String.to_atom with hardcoded string" do
    source = """
    defmodule MyModule do
      def convert() do
        String.to_atom("hello")
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule UnpinnedQueryBindingsTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.UnpinnedQueryBindings

  test "detects unpinned variable in query" do
    source = """
    defmodule Query do
      def by_id(user_id) do
        from(u in User, where: u.id == ^user_id)
      end

      def by_name(name) do
        from(u in User, where: u.name == name)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("pin") end)
  end
end

defmodule ObanAtomKeysTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.ObanAtomKeys

  test "detects atom keys in Oban worker" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: %{user_id: id}}) do
        IO.inspect(id)
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> assert_issue(fn [issue | _] -> assert issue.message |> String.contains?("atom key") end)
  end

  test "does not flag string keys in Oban worker" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: %{"user_id" => id}}) do
        IO.inspect(id)
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoExternalResourceTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.NoExternalResource

  test "detects File.read without @external_resource" do
    source = """
    defmodule MyModule do
      @html File.read!("templates/index.html")
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("@external_resource") end)
  end
end

defmodule ObanStructInArgsTest do
  use Credo.Test.Case

  @check Credo.Check.IronLaw.ObanStructInArgs

  test "does not flag plain map in Oban args" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        MyApp.Worker.new(%{user_id: args["user_id"]})
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end