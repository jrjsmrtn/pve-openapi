# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapiTest do
  use ExUnit.Case, async: true

  describe "versions/0" do
    test "returns non-empty sorted list" do
      versions = PveOpenapi.versions()
      assert [_ | _] = versions
      assert versions == Enum.sort(versions)
    end

    test "all versions are major.minor strings" do
      for v <- PveOpenapi.versions() do
        assert Regex.match?(~r/^\d+\.\d+$/, v), "expected major.minor, got: #{v}"
      end
    end

    test "first version is >= 7.0" do
      [first | _] = PveOpenapi.versions()
      assert PveOpenapi.parse_version(first) >= [7, 0]
    end
  end

  describe "spec/1" do
    test "returns {:ok, spec} for valid version" do
      assert {:ok, spec} = PveOpenapi.spec("8.3")
      assert spec["openapi"] == "3.1.0"
      assert spec["info"]["version"] == "8.3"
    end

    test "returns {:error, :unknown_version} for invalid version" do
      assert {:error, :unknown_version} = PveOpenapi.spec("6.0")
    end
  end

  describe "spec!/1" do
    test "returns spec for valid version" do
      spec = PveOpenapi.spec!("9.0")
      assert is_map(spec["paths"])
    end

    test "raises for invalid version" do
      assert_raise ArgumentError, ~r/Unknown PVE version/, fn ->
        PveOpenapi.spec!("99.9")
      end
    end
  end

  describe "endpoints/1" do
    test "returns endpoint structs" do
      [first | _] = PveOpenapi.versions()
      endpoints = PveOpenapi.endpoints(first)
      assert endpoints != []
      assert %PveOpenapi.Endpoint{} = hd(endpoints)
    end

    test "endpoint count grows across versions" do
      versions = PveOpenapi.versions()
      count_first = length(PveOpenapi.endpoints(List.first(versions)))
      count_last = length(PveOpenapi.endpoints(List.last(versions)))
      assert count_last >= count_first
    end
  end

  describe "metadata/0" do
    test "returns metadata map with versions" do
      meta = PveOpenapi.metadata()
      assert is_list(meta["versions"])
      assert length(meta["versions"]) == length(PveOpenapi.versions())
    end
  end

  describe "parse_version/1" do
    test "parses version string to integer list" do
      assert PveOpenapi.parse_version("8.3") == [8, 3]
      assert PveOpenapi.parse_version("7.0") == [7, 0]
    end
  end
end
