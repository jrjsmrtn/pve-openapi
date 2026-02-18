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
      # /nodes/{node}/qemu GET only requires path param 'node' which is in the path
      assert :ok = Contract.validate_request("8.3", "/version", :get, %{})
    end

    test "fails for missing required parameters" do
      # POST /nodes/{node}/qemu requires vmid
      result = Contract.validate_request("8.3", "/nodes/{node}/qemu", :post, %{})
      assert {:error, reasons} = result
      assert is_list(reasons)
      assert Enum.any?(reasons, &String.contains?(&1, "Missing required parameter"))
    end

    test "fails for nonexistent endpoint" do
      result = Contract.validate_request("8.3", "/nonexistent", :get, %{})
      assert {:error, [reason]} = result
      assert String.contains?(reason, "not found")
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
