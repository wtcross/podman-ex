defmodule Podman.RequestOptionsTest do
  use ExUnit.Case, async: true

  alias Podman.{Error, RequestOptions}

  describe "put_params/3" do
    test "drops specified keys and inserts params" do
      opts = [foo: 1, params: %{existing: true}]
      params = %{"key" => "value"}

      result = RequestOptions.put_params(opts, params, [:foo])

      assert Keyword.get(result, :foo) == nil
      assert Keyword.get(result, :params) == params
    end

    test "omits params when empty map" do
      opts = [params: %{existing: true}]
      result = RequestOptions.put_params(opts, %{}, [])

      refute Keyword.has_key?(result, :params)
    end
  end

  describe "encode helpers" do
    test "encode_csv handles lists" do
      assert RequestOptions.encode_csv(["a", :b, 3]) == "a,b,3"
    end

    test "encode_csv handles single values" do
      assert RequestOptions.encode_csv(:name) == "name"
    end

    test "encode_map handles maps" do
      assert RequestOptions.encode_map(%{a: 1}) == ~s({"a":1})
    end

    test "encode_map handles keyword lists" do
      assert RequestOptions.encode_map(a: 1, b: 2) == ~s({"a":1,"b":2})
    end

    test "encode_map handles atoms" do
      assert RequestOptions.encode_map(:value) == "value"
    end
  end

  describe "classify/2" do
    test "returns classified error" do
      error = %Error{status: 404}

      assert {:error, %Error{reason: :not_found}} =
               RequestOptions.classify({:error, error}, %{404 => :not_found})
    end

    test "passes through non-error tuples" do
      assert RequestOptions.classify({:ok, :value}, %{404 => :not_found}) == {:ok, :value}
    end
  end
end
