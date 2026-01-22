defmodule ConvergenceWeb.HealthController do
  use ConvergenceWeb, :controller

  def show(conn, _params) do
    json(conn, %{ok: true})
  end
end
