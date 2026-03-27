# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.ContractTest do
  use ExUnit.Case, async: true

  alias PveOpenapi.Contract

  describe "validate_coverage/2" do
    test "reports coverage statistics" do
      implemented = [
        {"/version", :get},
        {"/nodes/{node}/qemu", :get},
        {"/nodes/{node}/qemu/{vmid}", :get}
      ]

      {:ok, report} = Contract.validate_coverage("8.3", implemented)
      assert report.version == "8.3"
      assert report.covered == 3
      assert report.total > 3
      assert report.missing != []
      assert report.extra == []
      assert report.coverage_pct > 0
    end

    test "reports extra endpoints not in spec" do
      implemented = [{"/nonexistent", :get}]

      {:ok, report} = Contract.validate_coverage("8.3", implemented)
      assert report.covered == 0
      assert [{"/nonexistent", :get}] = report.extra
    end
  end

  describe "validate_request/4" do
    test "passes for valid request with required params" do
      assert :ok = Contract.validate_request("8.3", "/version", :get, %{})
    end

    test "fails for missing required parameters" do
      result = Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{})
      assert {:error, errors} = result
      assert is_list(errors)
      assert Enum.any?(errors, &(&1.param == "vmid" && &1.error =~ "Missing"))
    end

    test "fails for nonexistent endpoint" do
      result = Contract.validate_request("8.3", "/nonexistent", :get, %{})
      assert {:error, [reason]} = result
      assert is_binary(reason)
      assert reason =~ "not found"
    end

    test "passes with correct parameter types" do
      assert :ok =
               Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{
                 "vmid" => 100,
                 "node" => "pve1"
               })
    end

    test "fails for wrong parameter type" do
      result =
        Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{
          "vmid" => "not_an_int",
          "node" => "pve1"
        })

      assert {:error, errors} = result
      assert Enum.any?(errors, &(&1.param == "vmid" && &1.error =~ "type"))
    end

    test "fails for value below minimum" do
      result =
        Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{
          "vmid" => 1,
          "node" => "pve1"
        })

      assert {:error, errors} = result
      assert Enum.any?(errors, &(&1.param == "vmid" && &1.error =~ "minimum"))
    end

    test "fails for value above maximum" do
      result =
        Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{
          "vmid" => 9_999_999_999,
          "node" => "pve1"
        })

      assert {:error, errors} = result
      assert Enum.any?(errors, &(&1.param == "vmid" && &1.error =~ "maximum"))
    end
  end

  describe "validate_response/5" do
    test "passes for known status code" do
      assert :ok = Contract.validate_response("8.3", "/version", :get, 200, %{})
    end

    test "passes for error status codes" do
      assert :ok = Contract.validate_response("8.3", "/version", :get, 401, nil)
    end

    test "fails for nonexistent endpoint" do
      result = Contract.validate_response("8.3", "/nonexistent", :get, 200, %{})
      assert {:error, _} = result
    end
  end
end
