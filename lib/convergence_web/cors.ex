defmodule ConvergenceWeb.CORS do
  import Plug.Conn

  @methods "GET,PUT,OPTIONS"
  @headers "content-type,authorization"

  def init(opts), do: opts

  def call(conn, _opts) do
    origin = List.first(get_req_header(conn, "origin"))

    if origin && allowed_origin?(origin) do
      conn =
        conn
        |> put_resp_header("access-control-allow-origin", allow_origin_value(origin))
        |> put_resp_header("vary", "Origin")

      if conn.method == "OPTIONS" do
        conn
        |> put_resp_header("access-control-allow-methods", @methods)
        |> put_resp_header("access-control-allow-headers", @headers)
        |> send_resp(204, "")
        |> halt()
      else
        conn
      end
    else
      conn
    end
  end

  defp allowed_origin?(origin) do
    origins = Application.get_env(:convergence, :cors_origins, [])
    origins == ["*"] or origin in origins
  end

  defp allow_origin_value(origin) do
    if Application.get_env(:convergence, :cors_origins, []) == ["*"] do
      "*"
    else
      origin
    end
  end
end
