########################################################################################
#                                    NODE DEFINITIONS
#
# Define your fleet as a list of node entries. Each entry supports:
#
#   Required:
#     - name            : Node type (e.g., "lighthouse-geth", "bootnode")
#     - count           : Number of instances
#     - cloud           : "digitalocean" or "hetzner"
#
#   Optional:
#     - validator_start : First validator index (default: 0)
#     - validator_end   : Last validator index (default: 0)
#     - size            : Instance size override (provider-specific)
#     - region          : Region override (digitalocean) or location (hetzner)
#     - supernode       : Force supernode=true/false (auto-detected from name)
#
# Examples:
#   { name = "bootnode", count = 1, cloud = "digitalocean" }
#   { name = "lighthouse-geth", count = 2, cloud = "hetzner", validator_start = 0, validator_end = 200 }
#   { name = "mev-relay", count = 1, cloud = "hetzner", size = "ccx53" }
#
########################################################################################

variable "nodes" {
  description = "List of node definitions for the devnet"
  default = [
    { name = "bootnode", count = 1, cloud = "hetzner" },
    { name = "lighthouse-geth", count = 1, cloud = "hetzner", validator_start = 0, validator_end = 200 },
    { name = "lighthouse-besu", count = 1, cloud = "hetzner", validator_start = 200, validator_end = 400 },
    { name = "lighthouse-ethrex", count = 1, cloud = "hetzner", validator_start = 400, validator_end = 600 },
    { name = "lodestar-geth", count = 1, cloud = "hetzner", validator_start = 600, validator_end = 800 },
    { name = "lodestar-besu", count = 1, cloud = "hetzner", validator_start = 800, validator_end = 1000 },
    { name = "lodestar-ethrex", count = 1, cloud = "hetzner", validator_start = 1000, validator_end = 1200 },
    { name = "lighthouse-nethermind", count = 1, cloud = "hetzner", validator_start = 1200, validator_end = 1400 },
    { name = "lodestar-nethermind", count = 1, cloud = "hetzner", validator_start = 1400, validator_end = 1600 },
    { name = "lighthouse-nimbusel", count = 1, cloud = "hetzner", validator_start = 1600, validator_end = 1800 },
    { name = "lodestar-nimbusel", count = 1, cloud = "hetzner", validator_start = 1800, validator_end = 2000 },
    { name = "lighthouse-reth", count = 1, cloud = "hetzner", validator_start = 2000, validator_end = 2200 },
    { name = "lodestar-reth", count = 1, cloud = "hetzner", validator_start = 2200, validator_end = 2400 },
    { name = "lighthouse-erigon", count = 1, cloud = "hetzner", validator_start = 2400, validator_end = 2600 },
    { name = "lodestar-erigon", count = 1, cloud = "hetzner", validator_start = 2600, validator_end = 2800 },
  ]
}
