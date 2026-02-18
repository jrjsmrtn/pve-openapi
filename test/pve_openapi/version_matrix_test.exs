# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.VersionMatrixTest do
  use ExUnit.Case, async: true

  alias PveOpenapi.VersionMatrix

  describe "endpoint_available?/3" do
    test "qemu endpoint available in all versions" do
      for v <- PveOpenapi.versions() do
        assert VersionMatrix.endpoint_available?("/nodes/{node}/qemu", :get, v),
               "expected /nodes/{node}/qemu GET to be available in #{v}"
      end
    end

    test "returns false for unknown version" do
      refute VersionMatrix.endpoint_available?("/version", :get, "6.0")
    end

    test "HA rules only available in 9.x+" do
      refute VersionMatrix.endpoint_available?("/cluster/ha/rules", :get, "8.4")
      assert VersionMatrix.endpoint_available?("/cluster/ha/rules", :get, "9.0")
    end
  end

  describe "endpoint_added_in/2" do
    test "returns earliest available version for universal endpoints" do
      added = VersionMatrix.endpoint_added_in("/version", :get)
      [first | _] = PveOpenapi.versions()
      assert added == first
    end

    test "returns 9.0 for HA rules" do
      assert "9.0" = VersionMatrix.endpoint_added_in("/cluster/ha/rules", :get)
    end

    test "returns nil for nonexistent endpoint" do
      assert is_nil(VersionMatrix.endpoint_added_in("/nonexistent", :get))
    end
  end

  describe "endpoints_for_version/1" do
    test "returns non-empty set for valid version" do
      set = VersionMatrix.endpoints_for_version("8.3")
      assert MapSet.size(set) > 0
    end

    test "returns empty set for unknown version" do
      set = VersionMatrix.endpoints_for_version("6.0")
      assert MapSet.size(set) == 0
    end

    test "later versions have more or equal endpoints" do
      versions = PveOpenapi.versions()
      size_first = MapSet.size(VersionMatrix.endpoints_for_version(List.first(versions)))
      size_last = MapSet.size(VersionMatrix.endpoints_for_version(List.last(versions)))
      assert size_last >= size_first
    end
  end

  describe "all_endpoints/0" do
    test "returns all endpoints across all versions" do
      all = VersionMatrix.all_endpoints()
      latest = VersionMatrix.endpoints_for_version(List.last(PveOpenapi.versions()))
      assert MapSet.size(all) >= MapSet.size(latest)
    end
  end

  describe "versions_for_endpoint/2" do
    test "/version is available in all versions" do
      versions = VersionMatrix.versions_for_endpoint("/version", :get)
      assert length(versions) == length(PveOpenapi.versions())
    end

    test "HA rules available in 9.x versions" do
      versions = VersionMatrix.versions_for_endpoint("/cluster/ha/rules", :get)
      assert Enum.all?(versions, &String.starts_with?(&1, "9."))
      assert "9.0" in versions
    end
  end
end
