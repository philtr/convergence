defmodule ConvergenceWeb.HealthControllerTest do
  use ConvergenceWeb.ConnCase, async: true

  test "GET /healthz returns ok", %{conn: conn} do
    conn = get(conn, ~p"/healthz")

    assert json_response(conn, 200) == %{"ok" => true}
  end
end
