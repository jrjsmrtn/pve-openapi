# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.SpecTest do
  use ExUnit.Case, async: true

  alias PveOpenapi.Spec

  setup do
    {:ok, spec} = PveOpenapi.spec("8.3")
    %{spec: spec}
  end

  describe "endpoints/1" do
    test "returns list of Endpoint structs", %{spec: spec} do
      endpoints = Spec.endpoints(spec)
      assert is_list(endpoints)
      assert endpoints != []

      ep = hd(endpoints)
      assert is_binary(ep.path)
      assert ep.method in [:get, :post, :put, :delete]
    end

    test "endpoints are sorted by path then method", %{spec: spec} do
      endpoints = Spec.endpoints(spec)
      paths = Enum.map(endpoints, & &1.path)
      assert paths == Enum.sort(paths)
    end
  end

  describe "endpoint_set/1" do
    test "returns MapSet of {path, method} tuples", %{spec: spec} do
      set = Spec.endpoint_set(spec)
      assert is_struct(set, MapSet)
      assert MapSet.member?(set, {"/nodes/{node}/qemu", :get})
    end
  end

  describe "stats/1" do
    test "returns path and operation counts", %{spec: spec} do
      stats = Spec.stats(spec)
      assert stats.paths > 0
      assert stats.operations > 0
      assert stats.operations >= stats.paths
    end
  end

  describe "operation/3" do
    test "returns operation for valid path and method", %{spec: spec} do
      assert {:ok, op} = Spec.operation(spec, "/version", :get)
      assert is_binary(op["operationId"])
    end

    test "returns :error for invalid path", %{spec: spec} do
      assert :error = Spec.operation(spec, "/nonexistent", :get)
    end
  end
end
