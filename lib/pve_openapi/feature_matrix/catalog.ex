# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Georges Martin
defmodule PveOpenapi.FeatureMatrix.Catalog do
  @moduledoc """
  Default feature grouping catalog for the PVE API.

  Maps semantic feature atoms to path-based detection rules. A feature is
  considered available in a version if **any** of its indicator paths exist
  in that version's spec.

  Feature atoms are aligned with existing consumer usage in
  `MockPveApi.Capabilities` and `Pvex.Compatibility`.

  ## Extending

  Pass a custom catalog to `FeatureMatrix.features_for_version/2`:

      my_catalog = PveOpenapi.FeatureMatrix.Catalog.default() ++ [
        {:my_feature, ["/my/custom/path"]}
      ]
      PveOpenapi.FeatureMatrix.features_for_version("9.0", my_catalog)
  """

  @type rule :: {atom(), [String.t()]}

  @doc """
  Returns the default feature catalog.

  Each entry is `{feature_atom, indicator_paths}` where a feature is available
  if any indicator path exists in the version's spec.
  """
  @spec default() :: [rule()]
  def default do
    [
      # --- Core (available since 7.0) ---
      {:vm_management, ["/nodes/{node}/qemu"]},
      {:container_management, ["/nodes/{node}/lxc"]},
      {:storage_management, ["/storage"]},
      {:cluster_management, ["/cluster/status"]},
      {:user_management, ["/access/users"]},
      {:backup_management, ["/cluster/backup"]},
      {:network_management, ["/nodes/{node}/network"]},
      {:firewall_management, ["/cluster/firewall"]},
      {:pool_management, ["/pools"]},
      {:ha_management, ["/cluster/ha"]},
      {:ceph_management, ["/nodes/{node}/ceph"]},

      # --- SDN (7.0+ basic, 8.1+ stable, 9.0+ fabrics) ---
      {:sdn, ["/cluster/sdn/vnets"]},
      {:sdn_fabrics, ["/cluster/sdn/fabrics"]},

      # --- Notifications (8.1+) ---
      {:notification_system, ["/cluster/notifications"]},
      {:notification_endpoints, ["/cluster/notifications/endpoints"]},

      # --- Resource mappings (8.0+) ---
      {:resource_mappings, ["/cluster/mapping/pci"]},

      # --- HA rules/affinity (9.0+) ---
      {:ha_rules, ["/cluster/ha/rules"]},

      # --- Backup enhancements ---
      {:backup_info, ["/cluster/backup-info/not-backed-up"]},

      # --- Hardware ---
      {:hardware_pci, ["/nodes/{node}/hardware/pci"]},

      # --- Realm sync (8.0+) ---
      {:realm_sync_jobs, ["/access/domains/{realm}/sync"]},

      # --- Access management ---
      {:tfa_management, ["/access/tfa"]},
      {:acl_management, ["/access/acl"]}
    ]
  end
end
