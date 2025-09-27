defmodule Podman.Kube do
  @moduledoc """
  Helpers for Podman's Kubernetes play and generate APIs.
  """

  alias Podman.{Client, Error, RequestOptions}

  @type manifest :: iodata()

  @error_map %{500 => :server_error}

  @spec play(Client.t(), manifest(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def play(%Client{} = client, manifest, opts \\ []) do
    params = Client.encode_query(opts, query_spec())

    content_type = Keyword.get(opts, :content_type, "plain/text")

    request_opts =
      opts
      |> Keyword.drop(query_keys())
      |> Keyword.delete(:content_type)
      |> RequestOptions.put_params(params, [])
      |> Keyword.put(:body, IO.iodata_to_binary(manifest))
      |> RequestOptions.prepend_header({"content-type", content_type})

    Client.post(client, ["libpod", "play", "kube"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec down(Client.t(), manifest(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def down(%Client{} = client, manifest, opts \\ []) do
    params = Client.encode_query(opts, [{:force, "force"}])
    content_type = Keyword.get(opts, :content_type, "plain/text")

    request_opts =
      opts
      |> Keyword.drop([:force])
      |> Keyword.delete(:content_type)
      |> RequestOptions.put_params(params, [])
      |> Keyword.put(:body, IO.iodata_to_binary(manifest))
      |> RequestOptions.prepend_header({"content-type", content_type})

    Client.delete(client, ["libpod", "play", "kube"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  @spec generate(Client.t(), [String.t()], keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def generate(%Client{} = client, names, opts \\ []) when is_list(names) and names != [] do
    params =
      Client.encode_query(opts, [
        {:service, "service"},
        {:type, "type"},
        {:replicas, "replicas"},
        {:no_trunc, "noTrunc"},
        {:podman_only, "podmanOnly"}
      ])
      |> Map.put("names", Enum.join(names, ","))

    request_opts =
      opts
      |> Keyword.drop([:service, :type, :replicas, :no_trunc, :podman_only])
      |> Keyword.delete(:params)
      |> Keyword.put(:params, params)
      |> Keyword.put(:compressed, false)
      |> Keyword.put(:decode_body, false)
      |> Keyword.put(:response, fn %Req.Response{body: body} -> body end)

    Client.get(client, ["libpod", "generate", "kube"], request_opts)
    |> RequestOptions.classify(@error_map)
  end

  defp query_spec do
    [
      {:annotations, "annotations", &encode_annotations/1},
      {:log_driver, "logDriver"},
      {:log_options, "logOptions", &RequestOptions.encode_csv/1},
      {:network, "network", &RequestOptions.encode_csv/1},
      {:no_hosts, "noHosts"},
      {:no_trunc, "noTrunc"},
      {:publish_ports, "publishPorts", &RequestOptions.encode_csv/1},
      {:publish_all_ports, "publishAllPorts"},
      {:replace, "replace"},
      {:service_container, "serviceContainer"},
      {:start, "start"},
      {:static_ips, "staticIPs", &RequestOptions.encode_csv/1},
      {:static_macs, "staticMACs", &RequestOptions.encode_csv/1},
      {:tls_verify, "tlsVerify"},
      {:userns, "userns"},
      {:wait, "wait"},
      {:build, "build"}
    ]
  end

  defp query_keys do
    Enum.map(query_spec(), fn
      {key, _field, _fun} -> key
      {key, _field} -> key
    end)
  end

  defp encode_annotations(%{} = annotations), do: Jason.encode!(annotations)
  defp encode_annotations(value) when is_binary(value), do: value
end
