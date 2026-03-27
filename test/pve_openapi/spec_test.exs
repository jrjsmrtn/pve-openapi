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

  describe "parameters_for/3" do
    test "returns structured parameter list", %{spec: spec} do
      assert {:ok, params} = Spec.parameters_for(spec, "/nodes/{node}/qemu", :post)
      assert is_list(params)
      assert params != []

      vmid = Enum.find(params, &(&1.name == "vmid"))
      assert vmid != nil
      assert vmid.type == "integer"
      assert vmid.required == true
      assert vmid.in == "body"
      assert is_map(vmid.schema)
    end

    test "includes path parameters", %{spec: spec} do
      assert {:ok, params} = Spec.parameters_for(spec, "/nodes/{node}/qemu", :post)

      node = Enum.find(params, &(&1.name == "node"))
      assert node != nil
      assert node.in == "path"
      assert node.required == true
    end

    test "returns :error for nonexistent path", %{spec: spec} do
      assert :error = Spec.parameters_for(spec, "/nonexistent", :get)
    end
  end

  describe "response_schema/4" do
    test "returns response schema for 200", %{spec: spec} do
      assert {:ok, schema} = Spec.response_schema(spec, "/version", :get, 200)
      assert is_map(schema)
    end

    test "returns :error for nonexistent endpoint", %{spec: spec} do
      assert :error = Spec.response_schema(spec, "/nonexistent", :get, 200)
    end
  end

  describe "required_parameters/3" do
    test "returns list of required parameter names", %{spec: spec} do
      assert {:ok, required} = Spec.required_parameters(spec, "/nodes/{node}/qemu", :post)
      assert is_list(required)
      assert "vmid" in required
      assert "node" in required
    end

    test "returns :error for nonexistent endpoint", %{spec: spec} do
      assert :error = Spec.required_parameters(spec, "/nonexistent", :get)
    end
  end
end
