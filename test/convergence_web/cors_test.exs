defmodule ConvergenceWeb.CorsTest do
  use ConvergenceWeb.ConnCase, async: true

  setup do
    previous = Application.get_env(:convergence, :cors_origins)
    Application.put_env(:convergence, :cors_origins, ["http://localhost:8000"])

    on_exit(fn ->
      Application.put_env(:convergence, :cors_origins, previous)
    end)

    :ok
  end

  test "adds CORS headers for allowed origins on normal requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:8000")
      |> get(~p"/api/rooms/hello")

    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:8000"]
    assert get_resp_header(conn, "vary") == ["Origin"]
  end

  test "handles preflight requests", %{conn: conn} do
    conn =
      conn
      |> put_req_header("origin", "http://localhost:8000")
      |> put_req_header("access-control-request-method", "PUT")
      |> options(~p"/api/rooms/hello")

    assert conn.status == 204
    assert get_resp_header(conn, "access-control-allow-origin") == ["http://localhost:8000"]
    assert get_resp_header(conn, "access-control-allow-methods") == ["GET,PUT,OPTIONS"]
  end
end
