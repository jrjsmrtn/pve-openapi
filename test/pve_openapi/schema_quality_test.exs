# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.SchemaQualityTest do
  use ExUnit.Case, async: true

  alias PveOpenapi.SchemaQuality

  setup do
    {:ok, spec} = PveOpenapi.spec("9.0")
    %{spec: spec}
  end

  describe "analyze_endpoint/3" do
    test "classifies /version GET as rich", %{spec: spec} do
      assert {:rich, details} = SchemaQuality.analyze_endpoint(spec, "/version", :get)
      assert details.type == "object"
      assert details.property_count > 0
    end

    test "classifies endpoints with null returns as opaque", %{spec: spec} do
      # POST /cluster/backup returns null
      assert {:opaque, details} = SchemaQuality.analyze_endpoint(spec, "/cluster/backup", :post)
      assert details.type == "null"
    end

    test "classifies list endpoints as rich", %{spec: spec} do
      assert {:rich, details} = SchemaQuality.analyze_endpoint(spec, "/nodes/{node}/qemu", :get)
      assert details.type == "array"
    end

    test "returns :error for nonexistent endpoint", %{spec: spec} do
      assert :error = SchemaQuality.analyze_endpoint(spec, "/nonexistent", :get)
    end
  end

  describe "quality_summary/1" do
    test "returns counts for all quality levels" do
      summary = SchemaQuality.quality_summary("9.0")
      assert is_integer(summary.rich)
      assert is_integer(summary.partial)
      assert is_integer(summary.opaque)
      assert summary.total == summary.rich + summary.partial + summary.opaque
      assert summary.total > 0
      assert summary.version == "9.0"
    end

    test "rich count is positive" do
      summary = SchemaQuality.quality_summary("9.0")
      assert summary.rich > 0
    end

    test "opaque count is positive" do
      summary = SchemaQuality.quality_summary("9.0")
      assert summary.opaque > 0
    end
  end

  describe "quality_report/1" do
    test "returns per-endpoint assessments" do
      report = SchemaQuality.quality_report("9.0")
      assert is_list(report)
      assert report != []

      for entry <- Enum.take(report, 5) do
        assert entry.quality in [:rich, :partial, :opaque]
        assert is_binary(entry.path)
        assert entry.method in [:get, :post, :put, :delete]
        assert is_map(entry.details)
      end
    end
  end

  describe "quality_diff/2" do
    test "returns improved and degraded lists" do
      diff = SchemaQuality.quality_diff("8.3", "9.0")
      assert is_list(diff.improved)
      assert is_list(diff.degraded)
    end

    test "no changes for same version" do
      diff = SchemaQuality.quality_diff("9.0", "9.0")
      assert diff.improved == []
      assert diff.degraded == []
    end
  end
end
