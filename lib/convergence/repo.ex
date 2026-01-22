defmodule Convergence.Repo do
  use Ecto.Repo,
    otp_app: :convergence,
    adapter: Ecto.Adapters.Postgres
end
