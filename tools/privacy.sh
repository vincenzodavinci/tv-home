#!/usr/bin/env bash
# Privacy controls for an Android TV over ADB. Everything here is reversible.
#
#   tools/privacy.sh status
#   tools/privacy.sh dns <hostname>      Private DNS (DoT), e.g. abc123.dns.nextdns.io
#   tools/privacy.sh dns off
#   tools/privacy.sh adid off|on         advertising-ID opt-out
#   tools/privacy.sh vpn <package> [1]   always-on VPN; 1 = lockdown (no internet if it drops)
#   tools/privacy.sh vpn off
#   tools/privacy.sh audit               known ad/telemetry packages on this TV
#
# Every setting is reversible; a factory reset also clears it. See docs/PRIVACY.md.
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${PY:-tools/venv/bin/python}"
tv() { "$PY" -I tools/tv.py "$@"; }

usage() {
  cat >&2 <<'EOF'
usage:
  tools/privacy.sh status
  tools/privacy.sh dns <hostname>      e.g. abc123.dns.nextdns.io or dns.adguard-dns.com
  tools/privacy.sh dns off
  tools/privacy.sh adid off|on
  tools/privacy.sh vpn <package> [1]   1 = lockdown
  tools/privacy.sh vpn off
  tools/privacy.sh audit
EOF
  exit 1
}

restore_dns() { # $1 = old mode, $2 = old specifier
  if [ -z "${2:-}" ] || [ "$2" = "null" ]; then
    echo "settings delete global private_dns_specifier"
  else
    echo "settings put global private_dns_specifier $2"
  fi
  if [ -z "${1:-}" ] || [ "$1" = "null" ]; then
    echo "settings delete global private_dns_mode"
  else
    echo "settings put global private_dns_mode $1"
  fi
}

case "${1:-status}" in
  status)
    printf '%s\n' \
      'printf "private DNS mode: %s\n" "$(settings get global private_dns_mode)"' \
      'printf "private DNS host: %s\n" "$(settings get global private_dns_specifier)"' \
      'printf "limit ad tracking: %s\n" "$(settings get secure limit_ad_tracking)"' \
      'printf "always-on VPN app: %s\n" "$(settings get global always_on_vpn_app)"' \
      'printf "VPN lockdown: %s\n" "$(settings get global always_on_vpn_lockdown)"' \
      'printf "VPN interface: %s\n" "$(ip link show tun0 2>/dev/null | head -1)"' \
      | tv --batch
    ;;

  dns)
    host="${2:-}"
    [ -n "$host" ] || usage
    if [ "$host" = "off" ]; then
      printf '%s\n' \
        'settings delete global private_dns_specifier' \
        'settings put global private_dns_mode opportunistic' \
        | tv --batch
      echo "Private DNS is back to opportunistic (the network's DNS)."
      exit 0
    fi
    case "$host" in
      *[!A-Za-z0-9.-]*) echo "Not a hostname: $host" >&2; exit 1 ;;
    esac
    old_mode=$(tv 'settings get global private_dns_mode' | tr -d '\r')
    old_spec=$(tv 'settings get global private_dns_specifier' | tr -d '\r')
    printf '%s\n' \
      "settings put global private_dns_specifier $host" \
      "settings put global private_dns_mode hostname" \
      | tv --batch
    echo "Private DNS set to $host."
    if [ "${3:-}" = "--no-verify" ]; then exit 0; fi
    echo "Testing name resolution (up to ~10s)…"
    if tv 'ping -c 1 example.com' >/dev/null 2>&1; then
      echo "✓ DNS works."
    else
      echo "✗ Name resolution failed; restoring the previous setting." >&2
      restore_dns "$old_mode" "$old_spec" | tv --batch
      echo "The network may block DoT (port 853), or the hostname is wrong. See docs/PRIVACY.md." >&2
      exit 1
    fi
    ;;

  adid)
    case "${2:-}" in
      off) v=1; label="opted out" ;;
      on)  v=0; label="opted back in" ;;
      *) usage ;;
    esac
    printf '%s\n' "settings put secure limit_ad_tracking $v" | tv --batch
    echo "Advertising ID: $label (limit_ad_tracking=$v)."
    echo "Google TV also has Settings → System → Privacy → Ads → Delete advertising ID."
    ;;

  vpn)
    pkg="${2:-}"
    [ -n "$pkg" ] || usage
    if [ "$pkg" = "off" ]; then
      printf '%s\n' \
        'settings delete global always_on_vpn_app' \
        'settings put global always_on_vpn_lockdown 0' \
        | tv --batch
      echo "Always-on VPN cleared. The VPN app itself may still be connected; disconnect it there."
      exit 0
    fi
    lockdown="${3:-0}"
    case "$lockdown" in 0|1) ;; *) echo "lockdown must be 0 or 1" >&2; exit 1 ;; esac
    if ! tv "pm path $pkg" | grep -q '^package:'; then
      echo "$pkg isn't installed on the TV. Install the VPN app first." >&2
      exit 1
    fi
    printf '%s\n' \
      "settings put global always_on_vpn_app $pkg" \
      "settings put global always_on_vpn_lockdown $lockdown" \
      | tv --batch
    echo "Always-on VPN: $pkg (lockdown=$lockdown)."
    [ "$lockdown" = 1 ] && echo "Lockdown is on: if the VPN drops, the TV has no internet until it reconnects."
    echo "Some TVs ignore this until you also pick the VPN in Settings → Network → VPN."
    ;;

  audit)
    printf '%s\n' \
      'echo "== user-installed apps =="' \
      'pm list packages -3' \
      'echo "== known ad/telemetry packages =="' \
      'd=$(pm list packages -d); e=$(pm list packages); for p in tv.samba.ssm tv.samba.ssm.ui com.sonyericsson.idd.agent com.qterics.da.product com.sony.dtv.da.service com.sony.dtv.crashlogcollector com.sony.dtv.sonybugreportsys com.sony.dtv.promos com.sony.dtv.sonyselect com.google.android.apps.tv.dreamx com.google.android.feedback; do if echo "$d" | grep -qx "package:$p"; then echo "disabled  $p"; elif echo "$e" | grep -qx "package:$p"; then echo "ENABLED   $p"; else echo "absent    $p"; fi; done' \
      'echo "== other packages with ad/telemetry names =="' \
      'pm list packages | grep -iE "samba|nielsen|conviva|doubleverify|moat|adsdk|adservice|advert|tracker|analytics|telemetry|appsflyer|adjust|kochava|crashlog" || true' \
      | tv --batch
    ;;

  *) usage ;;
esac
