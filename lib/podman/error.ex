defmodule Podman.Error do
  @moduledoc """
  Error struct returned by Podman client operations.

  Wraps networking and HTTP errors to provide richer context to callers.
  """

  @type t :: %__MODULE__{
          message: String.t(),
          status: nil | pos_integer(),
          reason: term() | nil,
          body: term() | nil,
          request: %{
            optional(:method) => atom(),
            optional(:url) => iodata(),
            optional(:params) => map() | keyword(),
            optional(:headers) => map() | list()
          }
        }

  defexception [
    :message,
    :status,
    :reason,
    :body,
    request: %{}
  ]

  @doc false
  @spec http_error(Req.Response.t(), keyword()) :: t()
  def http_error(%Req.Response{} = response, request_opts) do
    method = request_opts[:method]
    url = request_opts[:url]
    snippet = render_body(response.body)

    message =
      "HTTP #{response.status} returned#{format_method_path(method, url)}" <>
        maybe_append_body(snippet)

    %__MODULE__{
      message: message,
      status: response.status,
      body: response.body,
      request: Map.merge(%{}, Map.new(request_opts))
    }
  end

  @doc false
  @spec transport_error(term(), keyword()) :: t()
  def transport_error(reason, request_opts) do
    method = request_opts[:method]
    url = request_opts[:url]

    message =
      "Transport error#{format_method_path(method, url)}: #{inspect(reason)}"

    %__MODULE__{
      message: message,
      reason: reason,
      request: Map.merge(%{}, Map.new(request_opts))
    }
  end

  defp format_method_path(nil, nil), do: ""

  defp format_method_path(method, url) do
    cond do
      method && url ->
        " for #{String.upcase(to_string(method))} #{url}"

      url ->
        " for #{url}"

      method ->
        " for #{String.upcase(to_string(method))} request"

      true ->
        ""
    end
  end

  defp maybe_append_body(nil), do: ""
  defp maybe_append_body(""), do: ""
  defp maybe_append_body(snippet), do: ": #{snippet}"

  defp render_body(%{} = body), do: body |> Jason.encode!() |> truncate()
  defp render_body(body) when is_list(body), do: body |> inspect() |> truncate()
  defp render_body(body) when is_binary(body), do: truncate(body)
  defp render_body(body), do: body |> inspect() |> truncate()

  defp truncate(value) do
    value
    |> String.trim()
    |> case do
      "" -> ""
      trimmed when byte_size(trimmed) <= 200 -> trimmed
      trimmed -> String.slice(trimmed, 0, 200) <> "…"
    end
  end
end
