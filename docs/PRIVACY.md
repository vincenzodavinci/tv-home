# Privacy while streaming

tv-home already removes the TV's own ad and telemetry apps. This layer covers the other observers:
your DNS, your ISP, and the servers behind the apps. It reduces what they can see; it does not make
you anonymous. A VPN moves trust from your ISP to the VPN provider — it does not make you invisible.

## Who can see what

| Observer | What it can see | What helps |
|---|---|---|
| TV OS / Google | apps opened, advertising ID, usage and diagnostics, sometimes what is on screen (ACR) | debloat (done), ad-ID opt-out, Private DNS |
| Your ISP | DNS names, TLS server names, destination IPs, traffic volume | a VPN on the TV or at the router |
| Streaming app / add-on server | your IP, account, the titles you search and play | a VPN, a dedicated account, trusted add-ons |
| Torrent swarm (torrent add-ons only) | your IP while you download | don't join the swarm; use a debrid service or a VPN |
| Payment provider | who you are | unavoidable for paid services |

## Quick start

```bash
tools/privacy.sh status
tools/privacy.sh dns abc123.dns.nextdns.io   # or dns.adguard-dns.com
tools/privacy.sh adid off
# optional, after installing a TV VPN app:
tools/privacy.sh vpn com.wireguard.android
```

`dns` checks name resolution and automatically restores the old setting if it fails. Undo with
`dns off`, `adid on` and `vpn off`.

## Layer 1: Private DNS (whole TV, no root)

Android's Private DNS encrypts DNS with DNS-over-TLS (DoT) and, with a filtering resolver, blocks
known ad and tracker domains for every app on the TV.

Two good choices:

- **NextDNS** — <https://nextdns.io>. Free tier is 300k queries/month, with per-device configs,
  query logs and blocklists. Create a config, copy the DoT hostname `<id>.dns.nextdns.io`, then run
  `tools/privacy.sh dns <id>.dns.nextdns.io`. The dashboard shows every domain the TV looks up,
  which is the best way to see what it phones home to.
- **AdGuard DNS** — <https://adguard-dns.io>. No account needed. Use `dns.adguard-dns.com` for
  ads/trackers, or `family.adguard-dns.com` to also block adult content.

Caveats:

- DoT uses port 853. Some networks block it; the script reverts if resolution fails.
- A captive portal (hotel Wi-Fi) may not work until you run `tools/privacy.sh dns off`. Re-enable it
  after signing in.
- DNS filtering cannot block first-party telemetry sent to the same domain as the content (for
  example YouTube), and it does not hide your IP. It also cannot stop tracking by IP address.
- If an app breaks, check the NextDNS query log and allowlist the domain rather than turning the
  filter off completely.

## Layer 2: VPN / tunnel

A VPN hides the destination of your traffic from your ISP. It does not hide it from the VPN provider,
and the streaming service still knows your account and what you watched.

**On the TV.** Install a TV-compatible VPN app (Mullvad, Proton VPN and NordVPN are common choices),
sign in, connect once, then run `tools/privacy.sh vpn <package>` to ask Android to keep it always on.
`tools/privacy.sh vpn <package> 1` enables lockdown: if the VPN drops, the TV has no internet.
Some TVs ignore the ADB setting until you also select the VPN in Settings → Network → VPN.

Trade-offs: streaming services often block known VPN ranges, so you may need to switch servers.
Android TV supports one active VPN at a time. An app uses a little CPU/RAM, which is fine on a 4 GB
Sony.

**At the router (recommended for a travel box).** A small travel router with a WireGuard client
(for example GL.iNet, <https://www.gl-inet.com>) puts every device behind the tunnel, including the
TV. The TV needs no VPN app, apps cannot bypass it, and hotel captive portals are handled once on
the router. You can also route only the TV through the VPN and keep other devices direct. This is
probably the "private server or tunnel" your colleague meant.

**Self-hosted WireGuard on a VPS.** Gives you a stable IP and full control, but the VPS provider sees
your traffic, and streaming services may treat datacenter IPs as VPNs. It is good for remote access
to your home network; it is not anonymity.

What a VPN does **not** hide: your Stremio account, what you watch (the service sees it), payment
identity, browser fingerprint, or the fact that you are using a VPN.

## Layer 3: Stremio-specific

- **Every add-on is a third-party server.** It sees your IP and every catalog, search and stream
  request you send it. Add only add-ons you trust, and remove the ones you do not use.
- **Use a dedicated Stremio account.** Do not sign in with Google or Facebook if you want your
  viewing list separate from your main identity; use an email alias. The account holds your library
  and add-on list, so sign out on TVs you do not own.
- **Self-host add-ons you rely on.** If you run an add-on on your own server, its queries stay on
  your LAN; the streams still come from wherever the add-on points. This reduces exposure to random
  add-on operators, but it is not full anonymity.
- **Debrid services (TorBox, Real-Debrid) are not VPNs.** They download a torrent on their servers
  and give you an HTTPS stream. With a torrent-indexing add-on, the swarm sees the debrid server
  instead of your home IP. Your ISP still sees encrypted traffic to the debrid provider, the
  provider knows what you downloaded and who your account is, and none of this changes whether you
  have the right to watch the content. Use it only for content you can legally access; the setup
  belongs in the add-on's own docs, not in this repo. TorBox: <https://torbox.app>

## What I would do for this TV

1. NextDNS with ad/tracker blocklists, set with `tools/privacy.sh dns ...`. Watch the query log for a
   day and allowlist anything that breaks.
2. `tools/privacy.sh adid off`, plus Settings → System → Privacy on the TV: turn off **Usage &
   diagnostics** and **Ads personalization**, and delete the advertising ID.
3. If you want ISP-level privacy, use a router-level WireGuard tunnel rather than an app on the TV.
   If you want it only for Stremio, an on-TV VPN is enough.
4. Keep Stremio on official or licensed add-ons, and use a dedicated account. Skip Torrentio; if you
   use a debrid service for legal content, configure it in the add-on, not here.

## Verify

- `tools/privacy.sh status` — Private DNS, ad-ID flag, always-on VPN, and `tun0` if a VPN is up.
- `tools/privacy.sh audit` — user apps plus known ad/telemetry packages, enabled or disabled.
- The NextDNS dashboard — live query log for the TV.
- The VPN app — handshake/connection status; `ip link` on the TV showing `tun0`.

## Rollback

```bash
tools/privacy.sh dns off
tools/privacy.sh adid on
tools/privacy.sh vpn off
```

A factory reset clears all of it. The debloat rollback is
`tools/restore.sh examples/sony-bravia-ae2/debloat.txt`.

## Sony BRAVIA AE2 notes

- Android 14 (API 34), Google TV. Private DNS works; VPN settings may be under Settings → Network →
  VPN.
- Already disabled by the Sony list: Samba TV (ACR), Sony IDD/DA analytics, crash and bug reporting,
  promos, Sony Select, demo mode, and the ad-laden ambient screensaver.
- Do not disable `com.google.android.gms`, `com.android.tv.settings`, or the active launcher; the TV
  needs them.
