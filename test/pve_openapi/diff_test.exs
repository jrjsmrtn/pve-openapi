# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.DiffTest do
  use ExUnit.Case, async: true

  alias PveOpenapi.Diff

  describe "added_endpoints/2" do
    test "returns endpoints added between versions" do
      added = Diff.added_endpoints("8.3", "9.0")
      assert is_list(added)
      assert added != []

      # All added endpoints should be {path, method} tuples
      for {path, method} <- added do
        assert is_binary(path)
        assert method in [:get, :post, :put, :delete]
      end
    end

    test "returns empty list when comparing same version" do
      assert [] = Diff.added_endpoints("8.3", "8.3")
    end
  end

  describe "removed_endpoints/2" do
    test "returns endpoints removed between versions" do
      removed = Diff.removed_endpoints("7.0", "9.0")
      assert is_list(removed)
    end

    test "returns empty list when comparing same version" do
      assert [] = Diff.removed_endpoints("8.3", "8.3")
    end
  end

  describe "common_endpoints/2" do
    test "common endpoints exist between consecutive versions" do
      common = Diff.common_endpoints("8.3", "8.4")
      assert common != []
    end
  end

  describe "summary/2" do
    test "returns summary map" do
      summary = Diff.summary("7.0", "9.0")
      assert summary.from == "7.0"
      assert summary.to == "9.0"
      assert is_integer(summary.added)
      assert is_integer(summary.removed)
      assert is_integer(summary.common)
      assert is_integer(summary.breaking)
      assert summary.added > 0
    end

    test "no changes between same version" do
      summary = Diff.summary("8.3", "8.3")
      assert summary.added == 0
      assert summary.removed == 0
    end
  end

  describe "breaking_changes/2" do
    test "returns list of breaking change maps" do
      changes = Diff.breaking_changes("7.0", "9.0")
      assert is_list(changes)

      for change <- changes do
        assert change.type in [:endpoint_removed, :new_required_parameter]
        assert is_binary(change.path)
      end
    end
  end
end
