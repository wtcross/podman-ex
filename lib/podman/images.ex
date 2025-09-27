defmodule Podman.Images do
  @moduledoc """
  Interface for image-related Podman API endpoints using the Req-based client.
  """

  alias Podman.{Client, Error}

  @type image_ref :: String.t()

  @spec list(Client.t(), keyword()) :: {:ok, list()} | {:error, Error.t()}
  def list(%Client{} = client, opts \\ []) do
    params =
      Client.encode_query(opts, [
        {:all, "all"},
        {:filters, "filters", &Client.encode_filters/1}
      ])

    request_opts = put_params(opts, params, [:all, :filters])

    Client.get(client, ["libpod", "images", "json"], request_opts)
  end

  @spec inspect(Client.t(), image_ref(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def inspect(%Client{} = client, image_ref, opts \\ []) do
    Client.get(client, ["libpod", "images", image_ref, "json"], opts)
  end

  @spec pull(Client.t(), image_ref(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def pull(%Client{} = client, reference, opts \\ []) when is_binary(reference) do
    params =
      opts
      |> Client.encode_query([
        {:quiet, "quiet"},
        {:compat_mode, "compatMode"},
        {:arch, "Arch"},
        {:os, "OS"},
        {:variant, "Variant"},
        {:policy, "policy"},
        {:tls_verify, "tlsVerify"},
        {:all_tags, "allTags"}
      ])
      |> Map.put("reference", reference)

    registry_auth = Keyword.get(opts, :registry_auth)

    request_opts =
      opts
      |> Keyword.drop([
        :quiet,
        :compat_mode,
        :arch,
        :os,
        :variant,
        :policy,
        :tls_verify,
        :all_tags,
        :registry_auth
      ])
      |> Keyword.delete(:params)
      |> Keyword.put(:params, params)
      |> maybe_put_header("X-Registry-Auth", registry_auth)

    Client.post(client, ["libpod", "images", "pull"], request_opts)
  end

  defp put_params(opts, params, drop_keys) do
    opts
    |> Keyword.drop(drop_keys)
    |> Keyword.delete(:params)
    |> maybe_put(:params, params)
  end

  defp maybe_put(keyword_list, _key, params) when params == %{}, do: keyword_list
  defp maybe_put(keyword_list, key, params), do: Keyword.put(keyword_list, key, params)

  defp maybe_put_header(opts, _header, nil), do: opts

  defp maybe_put_header(opts, header, value) do
    headers =
      opts
      |> Keyword.get(:headers, [])
      |> Enum.reject(fn {name, _} ->
        String.downcase(to_string(name)) == String.downcase(header)
      end)
      |> List.insert_at(0, {header, value})

    opts
    |> Keyword.delete(:headers)
    |> Keyword.put(:headers, headers)
  end
end
