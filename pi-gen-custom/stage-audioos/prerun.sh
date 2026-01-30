#!/bin/bash
set -euo pipefail
# Copy repo payload into /tmp so stage script can rsync from there (pi-gen bind-mounts stage's files into /tmp inside chroot)
mkdir -p "${ROOTFS_DIR}/tmp/repo_payload"
rsync -a "${STAGE_DIR}/files/" "${ROOTFS_DIR}/tmp/repo_payload/"
