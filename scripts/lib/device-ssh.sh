#!/usr/bin/env bash
# The device SSH transport, defined once for deploy.sh and ui.sh.
#
# Knulli runs dropbear over an exFAT /userdata partition. Permissions cannot be
# tightened on a fuseblk mount, so dropbear rejects public-key auth outright —
# hence password auth via sshpass whenever SSHPASS is set.
#
# WHY THIS IS SHARED RATHER THAN COPIED
#
# deploy.sh and ui.sh each built this block themselves, and they had already
# drifted: deploy.sh's ssh and scp were missing the
# -o StrictHostKeyChecking=accept-new that its own RSYNC_RSH on the very next
# line carried, and that ui.sh carried too. The visible effect was that against
# a device not yet in known_hosts, `deploy.sh sync` worked while
# `deploy.sh shot` / `logs` / `shell` failed with sshpass exit 6 — which reads
# as a flaky device, not as two transports disagreeing about one flag. Building
# all three from one option list makes that class of drift unrepresentable.
#
# Note that accept-new is trust-on-first-use, not a disabled check: a key that
# CHANGES after first contact still aborts. That is the right trade for a
# LAN handheld that gets reflashed, where the alternative in practice is
# people reaching for StrictHostKeyChecking=no.
#
# Sets, for the caller:
#   SSH   array — ssh, ready for "${SSH[@]}" "${DEVICE}" 'cmd'
#   SCP   array — scp, ready for "${SCP[@]}" src dst
#   RSYNC_RSH   exported, so plain `rsync` uses the same transport
#
# Arrays, not strings: the previous `$SSH` in deploy.sh relied on unquoted word
# splitting, which breaks the moment an option or a path contains a space.

# Trust-on-first-use, and force password auth so a stale local key does not
# consume the single authentication attempt dropbear allows.
DEVICE_SSH_OPTS=(
  -o PreferredAuthentications=password
  -o PubkeyAuthentication=no
  -o StrictHostKeyChecking=accept-new
)

device_ssh_setup() {
  if [[ -z "${SSHPASS:-}" ]]; then
    SSH=(ssh)
    SCP=(scp)
    return 0
  fi

  if ! command -v sshpass >/dev/null 2>&1; then
    echo "SSHPASS is set but 'sshpass' is not installed." >&2
    echo "Install with: brew install hudochenkov/sshpass/sshpass" >&2
    exit 1
  fi

  export SSHPASS
  SSH=(sshpass -e ssh "${DEVICE_SSH_OPTS[@]}")
  SCP=(sshpass -e scp "${DEVICE_SSH_OPTS[@]}")
  # rsync takes its transport as one string, not an array.
  export RSYNC_RSH="sshpass -e ssh ${DEVICE_SSH_OPTS[*]}"
}
