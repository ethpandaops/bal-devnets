////////////////////////////////////////////////////////////////////////////////////////
//                                   DNS NAMES
////////////////////////////////////////////////////////////////////////////////////////

data "cloudflare_zone" "default" {
  name = "ethpandaops.io"
}

locals {
  bootnodes = merge(
    {
      for vm in local.digitalocean_vms : vm.id => {
        name     = vm.name
        has_ipv6 = vm.ipv6
        ipv4     = digitalocean_droplet.main[vm.id].ipv4_address
        ipv6     = try(digitalocean_droplet.main[vm.id].ipv6_address, null)
      } if can(regex("bootnode", vm.name))
    },
    {
      for vm in local.hcloud_vms : vm.id => {
        name     = vm.name
        has_ipv6 = vm.ipv6_enabled
        ipv4     = hcloud_server.main[vm.id].ipv4_address
        ipv6     = try(hcloud_server.main[vm.id].ipv6_address, null)
      } if can(regex("bootnode", vm.name))
    }
  )
}

resource "cloudflare_record" "server_record_v4" {
  for_each = local.bootnodes
  zone_id  = data.cloudflare_zone.default.id
  name     = "${each.value.name}.${var.ethereum_network}"
  type     = "A"
  value    = each.value.ipv4
  proxied  = false
  ttl      = 120
}

resource "cloudflare_record" "server_record_v6" {
  for_each = { for k, v in local.bootnodes : k => v if v.has_ipv6 }
  zone_id  = data.cloudflare_zone.default.id
  name     = "${each.value.name}.${var.ethereum_network}"
  type     = "AAAA"
  value    = each.value.ipv6
  proxied  = false
  ttl      = 120
}

resource "cloudflare_record" "server_record_ns" {
  for_each = local.bootnodes
  zone_id  = data.cloudflare_zone.default.id
  name     = "srv.${var.ethereum_network}"
  type     = "NS"
  value    = "${each.value.name}.${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  proxied  = false
  ttl      = 120
}

////////////////////////////////////////////////////////////////////////////////////////
//                              CLOUDFLARE ACCESS (chat)
////////////////////////////////////////////////////////////////////////////////////////

// AI chat (panda-chat). Unlike the spamoor/authenticatoor apps (which only
// guard /auth/*), the WHOLE host is gated: Open-WebUI consumes the verified
// identity via trusted-header SSO (Cf-Access-Authenticated-User-Email) and
// forwards Cf-Access-Jwt-Assertion for per-user attribution, so every request
// must pass Access. Allow group mirrors the devnet's existing gate.
resource "cloudflare_access_application" "chat" {
  zone_id          = data.cloudflare_zone.default.id
  name             = "chat-${var.ethereum_network}-application"
  domain           = "chat.${var.ethereum_network}.${data.cloudflare_zone.default.name}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_access_policy" "chat" {
  application_id = cloudflare_access_application.chat.id
  zone_id        = data.cloudflare_zone.default.id
  name           = "chat-${var.ethereum_network}-policy"
  precedence     = 1
  decision       = "allow"
  include {
    group = ["6999654c-cbde-46f7-8308-f0e61bd4f69a"] # "Ethereum Github Organization" Access group
  }
}
