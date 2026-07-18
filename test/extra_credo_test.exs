defmodule ExtraCredoTest do
  use ExUnit.Case

  test "returns all check modules" do
    checks = ExtraCredo.checks()
    assert is_list(checks)
    assert length(checks) == 19
    assert Credo.Check.Extra.NoFloatForMoney in checks
  end
end

defmodule NoAssignNewInMountTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoAssignNewInMount

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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("assign_new") end)
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

  test "detects assign_new with atom key in mount" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign_new(:locale, fn -> "en" end)
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("assign_new") end)
  end
end

defmodule NoAuthInHandleEventTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoAuthInHandleEvent

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

  test "accepts custom auth_functions when configured" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        if may_access?(socket.assigns.user) do
          {:noreply, socket}
        end
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check, auth_functions: ~w(may_access?))
    |> refute_issues()
  end

  test "flags default auth_functions when only custom ones are configured" do
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
    |> run_check(@check, auth_functions: ~w(may_access?))
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("authorization")
    end)
  end

  test "accepts auth check via module function call" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        if MyApp.Auth.authorized?(socket.assigns.user) do
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

  test "accepts auth check via case statement with authorized?" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        case authorized?(socket.assigns.user) do
          true -> {:noreply, socket}
          false -> {:noreply, put_flash(socket, :error, "no")}
        end
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips non-live files for auth check" do
    source = """
    defmodule MyController do
      def index(conn, _params) do
        {:ok, conn}
      end
    end
    """

    source
    |> to_source_file("my_controller.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "accepts auth check via with block" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        with {:ok, user} <- fetch_user(socket) do
          if authorized?(user) do
            {:noreply, socket}
          end
        end
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "accepts auth check via case on subject" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", _params, socket) do
        case authorized?(socket.assigns.user) do
          true -> {:noreply, socket}
          false -> {:noreply, socket}
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

  @check Credo.Check.Extra.NoBareChangesetError

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

  test "detects bare {:error, err} with named variable" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.update(params) do
          {:ok, result} -> {:noreply, socket}
          {:error, err} -> {:noreply, socket}
        end
      end
    end
    """

    source
    |> to_source_file("my_liveview_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("changeset") end)
  end

  test "does not flag matched changeset" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.update(params) do
          {:ok, result} -> {:noreply, socket}
          {:error, %Ecto.Changeset{} = cs} -> {:noreply, assign(socket, form: to_form(cs))}
        end
      end
    end
    """

    source
    |> to_source_file("my_liveview_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects bare error in nested case" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        if some_condition do
          case MyApp.insert(params) do
            {:ok, result} -> {:noreply, socket}
            {:error, _} -> {:noreply, socket}
          end
        end
      end
    end
    """

    source
    |> to_source_file("my_liveview_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("changeset") end)
  end

  test "does not flag changeset case with proper match" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.update(params) do
          {:ok, result} -> {:noreply, socket}
          {:error, %Ecto.Changeset{} = cs} -> {:noreply, assign(socket, form: to_form(cs))}
        end
      end
    end
    """

    source
    |> to_source_file("my_liveview_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag non-changeset case subject" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case some_other_func(params) do
          {:ok, result} -> {:noreply, socket}
          {:error, _} -> {:noreply, socket}
        end
      end
    end
    """

    source
    |> to_source_file("my_liveview_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects bare error with insert function call" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.Repo.insert(params) do
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

  test "detects bare error with create_ function" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.create_user(params) do
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

  test "detects bare error with cast call" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case Ecto.Changeset.cast(params, [:field], []) do
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

  test "skips non-live files for bare changeset check" do
    source = """
    defmodule MyModule do
      def some_func(params) do
        case MyApp.update(params) do
          {:ok, result} -> result
          {:error, _} -> :error
        end
      end
    end
    """

    source
    |> to_source_file("my_module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects bare error with update_ function" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.update_user(params) do
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

  test "detects bare error with delete_ function" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.delete_user(params) do
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

  test "detects bare error with changeset function name" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.user_changeset(params) do
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

  test "detects bare error with insert_ function" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.insert_user(params) do
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

  test "skips non-matching function name" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_event("save", params, socket) do
        case MyApp.some_other_func(params) do
          {:ok, result} -> {:noreply, socket}
          {:error, _} -> {:noreply, socket}
        end
      end
    end
    """

    source
    |> to_source_file("my_liveview_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoFloatForMoneyTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoFloatForMoney

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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?(":float") end)
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

  test "detects :float for custom money keywords when configured" do
    source = """
    defmodule Product do
      use Ecto.Schema

      field :bucks, :float
    end
    """

    source
    |> to_source_file("product.ex")
    |> run_check(@check, money_keywords: ~w(bucks moolah))
    |> assert_issue(fn issue -> assert issue.message |> String.contains?(":float") end)
  end

  test "does not flag default money keywords when custom ones are configured and exclude them" do
    source = """
    defmodule Product do
      use Ecto.Schema

      field :price, :float
    end
    """

    source
    |> to_source_file("product.ex")
    |> run_check(@check, money_keywords: ~w(bucks moolah))
    |> refute_issues()
  end

  test "detects :float for money field in migration add" do
    source = """
    defmodule MyMigration do
      use Ecto.Migration

      def change do
        alter table(:products) do
          add :price, :float
        end
      end
    end
    """

    source
    |> to_source_file("migration.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?(":float") end)
  end
end

defmodule NoImplicitCrossJoinTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoImplicitCrossJoin

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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("cross join") end)
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

  test "does not flag explicit left_join" do
    source = """
    defmodule Query do
      def query do
        from(a in Account, left_join: b in assoc(a, :bookings), on: true)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag single binding in from" do
    source = """
    defmodule Query do
      def query do
        from(a in Account, select: a.name)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag right_join clause" do
    source = """
    defmodule Query do
      def query do
        from(a in Account, right_join: b in assoc(a, :bookings), on: true)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag cross_join clause" do
    source = """
    defmodule Query do
      def query do
        from(a in Account, cross_join: b in assoc(a, :bookings), on: true)
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

  @check Credo.Check.Extra.NoPubsubWithoutConnected

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
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("connected?") end)
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

  test "detects bare subscribe call (no module prefix)" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        subscribe("topic")
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("connected?") end)
  end

  test "does not flag subscribe with Phoenix.LiveView.connected? guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if Phoenix.LiveView.connected?(socket) do
          Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        end
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag subscribe with Phoenix.LiveView.Socket.connected? guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if Phoenix.LiveView.Socket.connected?(socket) do
          Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        end
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips non-live files for pubsub check" do
    source = """
    defmodule MyController do
      def index(conn, _params) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        {:ok, conn}
      end
    end
    """

    source
    |> to_source_file("my_controller.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips non-pubsub calls in live file" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        Phoenix.PubSub.broadcast(MyApp.PubSub, "topic", :msg)
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects subscribe guarded by non-connected? condition" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if some_condition do
          Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        end
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("connected?") end)
  end

  test "does not flag subscribe in non-live file without guard" do
    source = """
    defmodule MyController do
      def index(conn, _params) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        {:ok, conn}
      end
    end
    """

    source
    |> to_source_file("controller.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "issue function uses meta line for issue line number" do
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
    |> to_source_file("page_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("connected?") end)
  end
end

defmodule NoRawUntrustedTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoRawUntrusted

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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
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

  test "detects Phoenix.HTML.raw with variable" do
    source = """
    defmodule MyView do
      def render(assigns) do
        Phoenix.HTML.raw(@user_bio)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "does not flag Phoenix.HTML.raw with hardcoded string" do
    source = """
    defmodule MyView do
      def render(assigns) do
        Phoenix.HTML.raw("<p>Static content</p>")
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects raw with get_in" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(get_in(assigns, [:nested]))
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "detects raw with elem" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(elem(assigns, 0))
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "does not flag raw with binary concatenation" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(<<65, 66, 67>>)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects raw with case expression" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(case x do 1 -> "a"; _ -> "b" end)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "detects raw with if expression" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(if true, do: "a", else: "b")
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "does not flag raw with function references" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(&some_function/1)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag raw with anonymous function" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(fn -> "static" end)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects raw with cond expression" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(cond do true -> "a" end)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "detects raw with with expression" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(with {:ok, x} <- func(), do: x)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "detects raw with try expression" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(try do func() rescue _ -> "err" end)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "detects raw with receive expression" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(receive do msg -> msg end)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "detects raw with access_key call" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(access_key(:secret))
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "does not flag raw with charlist literal" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw('hello')
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag raw with ~s sigil" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(~s(hello))
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag raw with ~c sigil" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(~c(hello))
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects raw with function call result" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(get_user_input())
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end

  test "does not flag Phoenix.HTML.raw with no args" do
    source = """
    defmodule MyView do
      def render(assigns) do
        Phoenix.HTML.raw()
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects raw with for comprehension" do
    source = """
    defmodule MyView do
      def render(assigns) do
        raw(for x <- [1,2,3], do: x)
      end
    end
    """

    source
    |> to_source_file("my_view.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XSS") end)
  end
end

defmodule UnpinnedQueryBindingsTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.UnpinnedQueryBindings

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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "does not flag query where all variables are pinned" do
    source = """
    defmodule Query do
      def by_id(user_id) do
        from(u in User, where: u.id == ^user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects unpinned variable in where/3 keyword query" do
    source = """
    defmodule Query do
      def by_id(query, user_id) do
        where(query, [u], u.id == user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "does not flag pinned variable in where/3 keyword query" do
    source = """
    defmodule Query do
      def by_id(query, user_id) do
        where(query, [u], u.id == ^user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects unpinned variable in dynamic/2 expression" do
    source = """
    defmodule Query do
      def build_dynamic(user_id) do
        dynamic([u], u.id == user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "does not flag pinned variable in dynamic/2 expression" do
    source = """
    defmodule Query do
      def build_dynamic(user_id) do
        dynamic([u], u.id == ^user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects unpinned variable in piped where/3" do
    source = """
    defmodule Query do
      def by_id(user_id) do
        User
        |> where([u], u.id == user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "does not flag pinned variable in piped where/3" do
    source = """
    defmodule Query do
      def by_id(user_id) do
        User
        |> where([u], u.id == ^user_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects unpinned variable in having" do
    source = """
    defmodule Query do
      def active_users(min_count) do
        User
        |> group_by([u], u.id)
        |> having([u], count(u.id) > min_count)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "detects unpinned variable in order_by" do
    source = """
    defmodule Query do
      def sorted(column) do
        User
        |> order_by([u], ^column)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects unpinned variable with != operator" do
    source = """
    defmodule Query do
      def not_id(bad_id) do
        from(u in User, where: u.id != bad_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "detects unpinned variable with and/or in where" do
    source = """
    defmodule Query do
      def search(name, email) do
        from(u in User, where: u.name == name and u.email == email)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end

  test "detects unpinned variable in from with join" do
    source = """
    defmodule Query do
      def search(post_id) do
        from(p in Post, join: c in Comment, on: c.post_id == p.id, where: c.body == post_id)
      end
    end
    """

    source
    |> to_source_file("query.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("pin") end)
  end
end

defmodule ObanAtomKeysTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.ObanAtomKeys

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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("atom key") end)
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

  test "skips non-worker files" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: %{user_id: id}}) do
        IO.inspect(id)
      end
    end
    """

    source
    |> to_source_file("my_controller.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects atom keys in _job.ex files" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: %{user_id: id}}) do
        IO.inspect(id)
      end
    end
    """

    source
    |> to_source_file("some_job.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("atom key") end)
  end

  test "detects atom keys with alt pattern match" do
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
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("atom key") end)
  end

  test "skips non-matching struct pattern in worker" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%OtherStruct{args: %{user_id: id}}) do
        IO.inspect(id)
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips perform without struct arg" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(job) do
        IO.inspect(job)
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips non-perform function in worker" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def other_func(%Oban.Job{args: %{user_id: id}}) do
        IO.inspect(id)
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag perform with args variable" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: arg}) do
        IO.inspect(arg)
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag Oban struct without args key" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{other: value}) do
        IO.inspect(value)
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

  @check Credo.Check.Extra.NoExternalResource

  test "detects File.read without @external_resource" do
    source = """
    defmodule MyModule do
      @html File.read!("templates/index.html")
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("@external_resource")
    end)
  end

  test "does not flag File.read with @external_resource" do
    source = """
    defmodule MyModule do
      @external_resource "templates/index.html"
      @html File.read!("templates/index.html")
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag File.read inside function" do
    source = """
    defmodule MyModule do
      def load do
        File.read!("templates/index.html")
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects File.read without @external_resource (stream)" do
    source = """
    defmodule MyModule do
      @data File.stream!("data.csv")
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("@external_resource")
    end)
  end
end

defmodule ObanStructInArgsTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.ObanStructInArgs

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

  test "detects struct in Oban.insert! args" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(%{user: %User{id: 1}})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("struct") end)
  end

  test "detects struct in MyApp.Worker.new args" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def schedule do
        MyApp.Worker.new(%{user: %User{id: 1}})
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("struct") end)
  end

  test "detects struct in MyApp.Worker.perform_async args" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def schedule do
        MyApp.Worker.perform_async(%{user: %User{id: 1}})
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("struct") end)
  end

  test "does not flag plain map in Oban.insert!" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(%{user_id: 1})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects struct in Oban.insert via %Oban.Job wrapper" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert(%Oban.Job{args: %{user: %User{id: 1}}})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("struct") end)
  end

  test "skips non-struct map values in args" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(%{data: 42})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips when extract_args returns nil" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(42)
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "handles 2+ args call with extract_args catch-all" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(MyWorker, %{args: %User{}})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "handles single struct arg without args key" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(%User{id: 1})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "handles perform_async with map without args key" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def schedule do
        MyWorker.perform_async(%{other: 1})
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "handles new with map without args key" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def schedule do
        MyWorker.new(%{other: 1})
      end
    end
    """

    source
    |> to_source_file("my_worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips structs with string keys in args" do
    source = """
    defmodule MyApp do
      def schedule_job do
        Oban.insert!(%{"user" => %User{id: 1}})
      end
    end
    """

    source
    |> to_source_file("my_app.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoCommentsAsCommitMessagesTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoCommentsAsCommitMessages

  test "detects TODO comments" do
    source = """
    defmodule MyModule do
      # TODO: refactor this function
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("TODO") end)
  end

  test "detects issue references" do
    source = """
    defmodule MyModule do
      # Fixes #42
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("issue reference") end)
  end

  test "does not flag explanatory comments" do
    source = """
    defmodule MyModule do
      # The regex matches ISO 8601 timestamps
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects FIXME comments" do
    source = """
    defmodule MyModule do
      # FIXME: this is broken
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("FIXME") end)
  end

  test "detects HACK comments" do
    source = """
    defmodule MyModule do
      # HACK: temporary workaround
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("HACK") end)
  end

  test "detects XXX comments" do
    source = """
    defmodule MyModule do
      # XXX: needs review
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("XXX") end)
  end

  test "detects PR/URL references" do
    source = """
    defmodule MyModule do
      # See https://github.com/org/repo/pull/15
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("PR/URL") end)
  end

  test "handles parse errors gracefully" do
    source = """
    defmodule MyModule do
      def ok, do: :ok
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects commit-style messages" do
    source = """
    defmodule MyModule do
      # fixes #123
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("commit") end)
  end

  test "detects invalid syntax comment silently" do
    source = """
    defmodule MyModule do
      # this # is # fine
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag invalid issue function with valid syntax" do
    source = """
    defmodule MyModule do
      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoDbQueryInMountTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoDbQueryInMount

  test "detects Repo.get in mount/3" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        user = MyApp.Repo.get(User, socket.assigns.user_id)
        {:ok, assign(socket, :user, user)}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("mount") end)
  end

  test "does not flag Repo.get inside connected? guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if connected?(socket) do
          MyApp.Repo.get(User, socket.assigns.user_id)
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

  test "does not flag Repo.get inside assign_new" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign_new(:user, fn -> MyApp.Repo.get(User, 1) end)
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag inside assign_async" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign_async(:user, fn -> {:ok, %{user: MyApp.Repo.get(User, 1)}} end)
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag Repo.get inside Phoenix.LiveView.connected?" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if Phoenix.LiveView.connected?(socket) do
          MyApp.Repo.get(User, socket.assigns.user_id)
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

  test "does not flag Repo.get inside Phoenix.LiveView.Socket.connected?" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if Phoenix.LiveView.Socket.connected?(socket) do
          MyApp.Repo.get(User, socket.assigns.user_id)
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

  test "detects Repo.all in mount without guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        users = MyApp.Repo.all(User)
        {:ok, assign(socket, :users, users)}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("mount") end)
  end

  test "does not flag Repo call outside mount" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def handle_info(:refresh, socket) do
        user = MyApp.Repo.get(User, 1)
        {:noreply, assign(socket, :user, user)}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects Repo.get! in mount without guard" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        user = MyApp.Repo.get!(User, socket.assigns.user_id)
        {:ok, assign(socket, :user, user)}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("mount") end)
  end

  test "does not flag guarded by non-connected? condition" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        if some_condition do
          MyApp.Repo.get(User, socket.assigns.user_id)
        end
        {:ok, socket}
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("mount") end)
  end
end

defmodule NoDedupBeforeCastAssocTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoDedupBeforeCastAssoc

  test "detects cast_assoc without dedup" do
    source = """
    defmodule MyContext do
      def update_changeset(changeset, attrs) do
        Ecto.Changeset.cast_assoc(changeset, :items, with: &item_changeset/1)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("cast_assoc") end)
  end

  test "does not flag cast_assoc with preceding dedup" do
    source = """
    defmodule MyContext do
      def update_changeset(changeset, attrs) do
        items = Enum.uniq_by(attrs["items"], & &1.id)
        Ecto.Changeset.cast_assoc(changeset, :items, with: &item_changeset/1)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag cast_assoc with preceding Enum.dedup" do
    source = """
    defmodule MyContext do
      def update_changeset(changeset, attrs) do
        items = Enum.dedup(attrs["items"])
        Ecto.Changeset.cast_assoc(changeset, :items, with: &item_changeset/1)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects cast_assoc with Ecto.Changeset module" do
    source = """
    defmodule MyContext do
      def update_changeset(changeset, attrs) do
        Ecto.Changeset.cast_assoc(changeset, :items, with: &item_changeset/1)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("cast_assoc") end)
  end

  test "detects cast_assoc via dot module access" do
    source = """
    defmodule MyContext do
      def update_changeset(changeset, attrs) do
        some_mod.Changeset.cast_assoc(changeset, :items, with: &item_changeset/1)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("cast_assoc") end)
  end

  test "does not flag cast_assoc without dedup but with bare cast_assoc call" do
    source = """
    defmodule MyContext do
      def update_changeset(changeset, attrs) do
        cast_assoc(changeset, :items, with: &item_changeset/1)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("cast_assoc") end)
  end
end

defmodule NoDirectThirdPartyCallsTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoDirectThirdPartyCalls

  test "detects direct HTTPoison call" do
    source = """
    defmodule MyContext do
      def fetch(url) do
        HTTPoison.get(url)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("HTTPoison") end)
  end

  test "does not flag non-third-party calls" do
    source = """
    defmodule MyContext do
      def fetch(url) do
        MyApp.HttpClient.get(url)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects Tesla call" do
    source = """
    defmodule MyContext do
      def fetch(url) do
        Tesla.get(url)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("Tesla") end)
  end

  test "detects custom module configured via params" do
    source = """
    defmodule MyContext do
      def fetch(url) do
        MyCustomHTTP.get(url)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check, modules: ~w(MyCustomHTTP))
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("MyCustomHTTP") end)
  end

  test "does not flag variable-based remote calls" do
    source = """
    defmodule MyContext do
      def fetch(url) do
        client.get(url)
      end
    end
    """

    source
    |> to_source_file("context.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoLocaleInTaskClosureTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoLocaleInTaskClosure

  test "detects Gettext call in Task.async without locale capture" do
    source = """
    defmodule MyModule do
      def async_translate do
        Task.async(fn ->
          Gettext.dgettext(MyApp.Gettext, "domain", "message")
        end)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("locale") end)
  end

  test "does not flag when locale is captured" do
    source = """
    defmodule MyModule do
      def async_translate do
        locale = Gettext.get_locale()
        Task.async(fn ->
          Gettext.put_locale(locale)
          Gettext.dgettext(MyApp.Gettext, "domain", "message")
        end)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects Gettext in unqualified async" do
    source = """
    defmodule MyModule do
      def async_translate do
        async(fn ->
          Gettext.dgettext(MyApp.Gettext, "domain", "message")
        end)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("locale") end)
  end

  test "does not flag Gettext.gettext without Task" do
    source = """
    defmodule MyModule do
      def translate do
        Gettext.dgettext(MyApp.Gettext, "domain", "message")
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag Gettext.get_locale without Task" do
    source = """
    defmodule MyModule do
      def translate do
        Gettext.get_locale()
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoNonIdempotentJobsTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoNonIdempotentJobs

  test "detects Repo.insert! in perform/1" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        user = build_user(args)
        MyApp.Repo.insert!(user)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("insert!") end)
  end

  test "does not flag non-bang Repo.insert in perform/1" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        user = build_user(args)
        case MyApp.Repo.insert(user) do
          {:ok, _} -> {:ok, :done}
          {:error, _} -> {:ok, :done}
        end
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects Repo.update! in perform/1" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        MyApp.Repo.update!(args)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("update!") end)
  end

  test "detects Repo.delete! in perform/1" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        MyApp.Repo.delete!(args)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("delete!") end)
  end

  test "skips perform with non-oban struct arg" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%{other: val}) do
        MyApp.Repo.insert!(val)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "skips non-bang repo call in perform" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        MyApp.Repo.insert(args)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule ASTTraversalTest do
  use Credo.Test.Case

  alias ExtraCredo.ASTTraversal

  test "traverse handles non-tuple, non-list values" do
    result = ASTTraversal.traverse(:simple_atom, & &1)
    assert result == []
  end

  test "traverse handles list of values" do
    result =
      ASTTraversal.traverse([{:a, [], []}, {:b, [], []}], fn
        {name, _, _} -> name
        _ -> nil
      end)

    assert :a in result
    assert :b in result
  end

  test "flatten handles 2-tuple AST nodes" do
    result = ASTTraversal.flatten({:a, :b})
    assert {:a, :b} in result
  end

  test "flatten handles bare values" do
    result = ASTTraversal.flatten(:simple)
    assert :simple in result
  end

  test "collect_issues_with_path handles source" do
    source = """
    defmodule Test do
      def foo, do: :ok
    end
    """

    issues =
      source
      |> to_source_file("test.ex")
      |> ASTTraversal.collect_issues_with_path(fn _, _, _ -> nil end, [])

    assert issues == []
  end

  test "collect_issues_with_path passes through :do and :else blocks" do
    source = """
    defmodule Test do
      def foo(x) do
        if x, do: :ok, else: :error
      end
    end
    """

    issues =
      source
      |> to_source_file("test.ex")
      |> ASTTraversal.collect_issues_with_path(fn _, _, _ -> nil end, [])

    assert issues == []
  end
end

defmodule NoUnsupervisedProcessesTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoUnsupervisedProcesses

  test "detects GenServer.start_link outside supervisor" do
    source = """
    defmodule MyModule do
      def start_worker(opts) do
        GenServer.start_link(MyWorker, opts, name: __MODULE__)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("supervisor") end)
  end

  test "does not flag GenServer.start_link inside children/1" do
    source = """
    defmodule MySupervisor do
      use Supervisor

      def children(_opts) do
        [
          {MyWorker, opts}
        ]
      end
    end
    """

    source
    |> to_source_file("supervisor.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects Task.start_link outside supervisor" do
    source = """
    defmodule MyModule do
      def run do
        Task.start_link(fn -> :ok end)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("supervisor") end)
  end

  test "detects Agent.start outside supervisor" do
    source = """
    defmodule MyModule do
      def run do
        Agent.start(fn -> %{} end)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("supervisor") end)
  end

  test "does not flag process start inside defmodule ending in Supervisor" do
    source = """
    defmodule MyApp.Supervisor do
      def init(_opts) do
        children = [
          {MyWorker, []}
        ]
        Supervisor.init(children, strategy: :one_for_one)
      end
    end
    """

    source
    |> to_source_file("supervisor.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "detects Agent.start_link outside supervisor" do
    source = """
    defmodule MyModule do
      def run do
        Agent.start_link(fn -> %{} end)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("supervisor") end)
  end

  test "detects GenServer.start outside supervisor" do
    source = """
    defmodule MyModule do
      def run do
        GenServer.start(MyWorker, opts)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("supervisor") end)
  end

  test "detects start_link outside children function" do
    source = """
    defmodule MyApp.Supervisor do
      def init(_opts) do
        GenServer.start_link(MyWorker, opts)
      end
    end
    """

    source
    |> to_source_file("supervisor.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("supervisor") end)
  end

  test "does not flag GenServer.start_link in children" do
    source = """
    defmodule MyApp.Supervisor do
      def children(_opts) do
        [
          {MyWorker, opts}
        ]
      end
    end
    """

    source
    |> to_source_file("supervisor.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag GenServer.start_link inside :__aliases__ supervisor" do
    source = """
    defmodule MyApp.Supervisor do
      def init(_opts) do
        children = [
          {MyWorker, []}
        ]
        Supervisor.init(children, strategy: :one_for_one)
      end
    end
    """

    source
    |> to_source_file("mysupervisor.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag GenServer.start_link inside children function" do
    source = """
    defmodule MyModule do
      def children(_opts) do
        [
          GenServer.start_link(MyWorker, opts)
        ]
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "does not flag variable-based process start calls" do
    source = """
    defmodule MyModule do
      def run do
        client.start_link(opts)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end

  test "issue message uses 'Process' for non-aliased module calls" do
    source = """
    defmodule MyModule do
      def run do
        client.start_link(opts)
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoNonIdempotentExtraTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoNonIdempotentJobs

  test "detects Repo.update! in perform with Oban.Job.Args" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job.Args{args: args}) do
        MyApp.Repo.update!(args)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("update!") end)
  end

  test "detects Repo.delete! in perform" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        MyApp.Repo.delete!(args)
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("delete!") end)
  end

  test "does not flag perform with variable args" do
    source = """
    defmodule MyApp.Worker do
      use Oban.Worker

      def perform(%Oban.Job{args: args}) do
        {:ok, :done}
      end
    end
    """

    source
    |> to_source_file("worker.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoExternalResourceExtraTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoExternalResource

  test "detects File.read (non-bang) without @external_resource" do
    source = """
    defmodule MyModule do
      @data File.read("data.txt")
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("@external_resource")
    end)
  end

  test "does not flag File.read! inside function def" do
    source = """
    defmodule MyModule do
      def load do
        File.read!("data.txt")
      end
    end
    """

    source
    |> to_source_file("module.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end

defmodule NoAssignNewInMountExtraTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoAssignNewInMount

  test "detects assign_new with Phoenix.LiveView.Socket module" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign_new(:locale, fn -> "en" end)
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("assign_new") end)
  end

  test "does not flag assign_new with string key" do
    source = """
    defmodule MyLive do
      use Phoenix.LiveView

      def mount(_params, _session, socket) do
        socket
        |> assign_new("locale", fn -> "en" end)
      end
    end
    """

    source
    |> to_source_file("my_live.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?("key") end)
  end
end

defmodule NoFloatForMoneyExtraTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoFloatForMoney

  test "detects :float with :add in migration" do
    source = """
    defmodule MyMigration do
      use Ecto.Migration

      def change do
        alter table(:products) do
          add :amount, :float
        end
      end
    end
    """

    source
    |> to_source_file("migration.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?(":float") end)
  end

  test "detects configurable money keywords with add" do
    source = """
    defmodule MyMigration do
      use Ecto.Migration

      def change do
        alter table(:invoices) do
          add :total, :float
        end
      end
    end
    """

    source
    |> to_source_file("migration.ex")
    |> run_check(@check)
    |> assert_issue(fn issue -> assert issue.message |> String.contains?(":float") end)
  end
end

defmodule NoColorfulEmojiTest do
  use Credo.Test.Case

  @check Credo.Check.Extra.NoColorfulEmoji

  test "detects dingbat emoji (U+2700-U+27BF)" do
    source = """
    defmodule MyModule do
      @moduledoc \"\"\"
      This has a check mark: \u2705
      \"\"\"
    end
    """

    source
    |> to_source_file("my_module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("emoji")
      assert issue.trigger == "\u2705"
      assert issue.line_no == 3
    end)
  end

  test "detects miscellaneous symbols emoji (U+2600-U+26FF)" do
    source = """
    defmodule MyModule do
      @moduledoc \"\"\"
      Star: \u2605
      \"\"\"
    end
    """

    source
    |> to_source_file("my_module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("emoji")
      assert issue.trigger == "\u2605"
    end)
  end

  test "detects emoticon emoji (U+1F300-U+1F9FF)" do
    source = """
    defmodule MyModule do
      @moduledoc \"\"\"
      Rocket: \u{1F680}
      \"\"\"
    end
    """

    source
    |> to_source_file("my_module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("emoji")
      assert issue.trigger == "\u{1F680}"
    end)
  end

  test "detects extended pictograph emoji (U+1FA00-U+1FAFF)" do
    source = """
    defmodule MyModule do
      # \u{1FA75}
    end
    """

    source
    |> to_source_file("my_module.ex")
    |> run_check(@check)
    |> assert_issue(fn issue ->
      assert issue.message |> String.contains?("emoji")
    end)
  end

  test "detects multiple emoji on different lines" do
    source = """
    defmodule MyModule do
      # comment with \u2705
      @doc "also here: \u274C"
    end
    """

    issues =
      source
      |> to_source_file("my_module.ex")
      |> run_check(@check)

    assert length(issues) == 2
    assert Enum.any?(issues, fn i -> i.line_no == 2 end)
    assert Enum.any?(issues, fn i -> i.line_no == 3 end)
  end

  test "does not flag clean source without emoji" do
    source = """
    defmodule MyModule do
      @moduledoc \"\"\"
      No emoji here, just plain text.
      \"\"\"

      def my_func do
        :ok
      end
    end
    """

    source
    |> to_source_file("my_module.ex")
    |> run_check(@check)
    |> refute_issues()
  end
end
