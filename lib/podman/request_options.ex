defmodule Podman.RequestOptions do
  @moduledoc false

  alias Podman.Error

  def put_params(opts, params, drop_keys \\ []) do
    opts
    |> Keyword.drop(drop_keys)
    |> Keyword.delete(:params)
    |> maybe_put(:params, params)
  end

  def prepend_header(opts, header) do
    headers =
      opts
      |> Keyword.get(:headers, [])
      |> List.wrap()
      |> List.insert_at(0, header)

    opts
    |> Keyword.delete(:headers)
    |> Keyword.put(:headers, headers)
  end

  def encode_csv(nil), do: nil
  def encode_csv(list) when is_list(list), do: list |> Enum.map(&to_string/1) |> Enum.join(",")
  def encode_csv(value), do: to_string(value)

  def encode_map(nil), do: nil
  def encode_map(map) when is_map(map), do: Jason.encode!(map)
  def encode_map(list) when is_list(list), do: list |> Enum.into(%{}) |> Jason.encode!()
  def encode_map(value), do: to_string(value)

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, %{} = map) when map == %{}, do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  def classify({:error, %Error{} = error}, mapping) when is_map(mapping) do
    {:error, Error.classify(error, mapping)}
  end

  def classify(result, _mapping), do: result
end
