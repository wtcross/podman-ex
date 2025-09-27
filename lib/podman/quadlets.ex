defmodule Podman.Quadlets do
  @moduledoc """
  Helpers for generating systemd quadlet units via Podman's API.
  """

  alias Podman.{Client, Error, RequestOptions}

  @error_map %{500 => :server_error}

  @spec generate(Client.t(), String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def generate(%Client{} = client, name, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:use_name, "useName"},
        {:new, "new"},
        {:no_header, "noHeader"},
        {:start_timeout, "startTimeout"},
        {:stop_timeout, "stopTimeout"},
        {:restart_policy, "restartPolicy"},
        {:container_prefix, "containerPrefix"},
        {:pod_prefix, "podPrefix"},
        {:separator, "separator"},
        {:restart_sec, "restartSec"},
        {:wants, "wants", &RequestOptions.encode_csv/1},
        {:after, "after", &RequestOptions.encode_csv/1},
        {:requires, "requires", &RequestOptions.encode_csv/1},
        {:env, "additionalEnvVariables", &RequestOptions.encode_csv/1}
      ])

    request_opts =
      opts
      |> Keyword.drop([
        :use_name,
        :new,
        :no_header,
        :start_timeout,
        :stop_timeout,
        :restart_policy,
        :container_prefix,
        :pod_prefix,
        :separator,
        :restart_sec,
        :wants,
        :after,
        :requires,
        :env
      ])
      |> Keyword.delete(:params)
      |> Keyword.put(:params, params)
      |> Keyword.put(:decode_body, false)
      |> Keyword.put(:response, fn %Req.Response{body: body} -> body end)

    Client.get(client, ["libpod", "generate", name, "systemd"], request_opts)
    |> RequestOptions.classify(@error_map)
  end
end
