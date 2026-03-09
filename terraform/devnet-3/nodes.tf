########################################################################################
#                                    NODE DEFINITIONS
#
# Define your fleet as a list of node entries. Each entry supports:
#
#   Required:
#     - name            : Node type (e.g., "lighthouse-geth-super", "bootnode")
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
#   { name = "lighthouse-geth-super", count = 2, cloud = "hetzner", validator_start = 0, validator_end = 200 }
#   { name = "mev-relay", count = 1, cloud = "hetzner", size = "ccx53" }
#
########################################################################################

variable "nodes" {
  description = "List of node definitions for the devnet"
  default = [
    { name = "bootnode", count = 1, cloud = "hetzner" },
    { name = "lighthouse-geth-super", count = 1, cloud = "hetzner", validator_start = 0, validator_end = 200 },
    { name = "lighthouse-besu-super", count = 1, cloud = "hetzner", validator_start = 200, validator_end = 400 },
    { name = "lighthouse-nethermind-super", count = 1, cloud = "hetzner", validator_start = 400, validator_end = 600 },
    { name = "lighthouse-reth-super", count = 1, cloud = "hetzner", validator_start = 600, validator_end = 800 },
    { name = "lighthouse-nimbusel-super", count = 1, cloud = "hetzner", validator_start = 800, validator_end = 1000 },
    { name = "lodestar-geth-super", count = 1, cloud = "hetzner", validator_start = 1000, validator_end = 1200 },
    { name = "lodestar-nethermind-super", count = 1, cloud = "hetzner", validator_start = 1200, validator_end = 1400 },
    { name = "lodestar-besu-super", count = 1, cloud = "hetzner", validator_start = 1400, validator_end = 1600 },
    { name = "lodestar-reth-super", count = 1, cloud = "hetzner", validator_start = 1600, validator_end = 1800 },
    { name = "lodestar-nimbusel-super", count = 1, cloud = "hetzner", validator_start = 1800, validator_end = 2000 },
    { name = "lighthouse-ethrex-super", count = 1, cloud = "hetzner", validator_start = 2000, validator_end = 2200 },
    { name = "lodestar-ethrex-super", count = 1, cloud = "hetzner", validator_start = 2200, validator_end = 2400 },
    { name = "lighthouse-erigon-super", count = 1, cloud = "hetzner", validator_start = 2400, validator_end = 2600 },
    { name = "lodestar-erigon-super", count = 1, cloud = "hetzner", validator_start = 2600, validator_end = 2800 },
  ]
}
