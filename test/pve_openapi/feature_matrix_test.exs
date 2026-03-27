# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.FeatureMatrixTest do
  use ExUnit.Case, async: true

  alias PveOpenapi.FeatureMatrix

  describe "feature_available?/2" do
    test "core features available in all versions" do
      for version <- PveOpenapi.versions() do
        assert FeatureMatrix.feature_available?(:vm_management, version),
               "vm_management should be available in #{version}"

        assert FeatureMatrix.feature_available?(:container_management, version)
        assert FeatureMatrix.feature_available?(:storage_management, version)
      end
    end

    test "SDN fabrics only in 9.0+" do
      assert FeatureMatrix.feature_available?(:sdn_fabrics, "9.0")
      assert FeatureMatrix.feature_available?(:sdn_fabrics, "9.1")
      refute FeatureMatrix.feature_available?(:sdn_fabrics, "8.4")
      refute FeatureMatrix.feature_available?(:sdn_fabrics, "7.0")
    end

    test "HA rules only in 9.0+" do
      assert FeatureMatrix.feature_available?(:ha_rules, "9.0")
      refute FeatureMatrix.feature_available?(:ha_rules, "8.4")
    end

    test "notification system in 8.1+" do
      assert FeatureMatrix.feature_available?(:notification_system, "8.1")
      assert FeatureMatrix.feature_available?(:notification_system, "9.0")
      refute FeatureMatrix.feature_available?(:notification_system, "8.0")
    end

    test "resource mappings in 8.0+" do
      assert FeatureMatrix.feature_available?(:resource_mappings, "8.0")
      assert FeatureMatrix.feature_available?(:resource_mappings, "9.0")
      refute FeatureMatrix.feature_available?(:resource_mappings, "7.4")
    end

    test "unknown feature returns false" do
      refute FeatureMatrix.feature_available?(:nonexistent_feature, "9.0")
    end
  end

  describe "feature_added_in/1" do
    test "returns earliest version for core features" do
      assert "7.0" = FeatureMatrix.feature_added_in(:vm_management)
    end

    test "returns correct version for SDN fabrics" do
      assert "9.0" = FeatureMatrix.feature_added_in(:sdn_fabrics)
    end

    test "returns correct version for notification system" do
      assert "8.1" = FeatureMatrix.feature_added_in(:notification_system)
    end

    test "returns correct version for resource mappings" do
      assert "8.0" = FeatureMatrix.feature_added_in(:resource_mappings)
    end

    test "returns nil for unknown feature" do
      assert nil == FeatureMatrix.feature_added_in(:nonexistent)
    end
  end

  describe "features_for_version/1" do
    test "returns sorted list of feature atoms" do
      features = FeatureMatrix.features_for_version("9.0")
      assert is_list(features)
      assert features == Enum.sort(features)
      assert features != []
    end

    test "9.0 has more features than 7.0" do
      f90 = FeatureMatrix.features_for_version("9.0")
      f70 = FeatureMatrix.features_for_version("7.0")
      assert length(f90) > length(f70)
    end

    test "9.0 includes SDN fabrics and HA rules" do
      features = FeatureMatrix.features_for_version("9.0")
      assert :sdn_fabrics in features
      assert :ha_rules in features
    end

    test "7.0 does not include 9.0-only features" do
      features = FeatureMatrix.features_for_version("7.0")
      refute :sdn_fabrics in features
      refute :ha_rules in features
      refute :notification_system in features
    end

    test "accepts custom catalog" do
      catalog = [{:custom, ["/version"]}]
      features = FeatureMatrix.features_for_version("9.0", catalog)
      assert :custom in features
    end
  end

  describe "feature_diff/2" do
    test "returns added and removed features" do
      diff = FeatureMatrix.feature_diff("8.4", "9.0")
      assert is_list(diff.added)
      assert is_list(diff.removed)
      assert :sdn_fabrics in diff.added
      assert :ha_rules in diff.added
    end

    test "no diff for same version" do
      diff = FeatureMatrix.feature_diff("9.0", "9.0")
      assert diff.added == []
      assert diff.removed == []
    end
  end

  describe "all_features/0" do
    test "returns map of feature atoms to version lists" do
      all = FeatureMatrix.all_features()
      assert is_map(all)
      assert Map.has_key?(all, :vm_management)
      assert is_list(all[:vm_management])
    end
  end
end
