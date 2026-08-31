#!/usr/bin/env bash
#
# Builds (or rebuilds) an Ubuntu cloud-init VM template on Proxmox VE.
# This script is (probably) idempotent.
#

set -euo pipefail

# --------------------------------------------- C O N F I G U R A T I O N ----------------------------------------------

VMID=9000                                         # Proxmox VM ID for the template
TEMPLATE_NAME="template-ubuntu-2604"              # Name shown in the web UI

# Latest 26.04 LTS "Resolute Raccoon" build (this URL always points at
# the current point release; re-running the script picks up new builds)
IMG_URL="https://cloud-images.ubuntu.com/resolute/current/resolute-server-cloudimg-amd64.img"
IMG_DIR="/var/lib/vz/template/iso"                # where to stash the downloaded .img

STORAGE="local-lvm"                               # Storage for the template's disk
BRIDGE="vmbr0"                                    # Network bridge clones will use
CORES=2
MEMORY_MB=2048
ROOT_DISK_SIZE_GB=20                              # Size of cloned disks

# Empty strings = leave unset. Per-clone you can still do:
#   qm set <VMID> --cipassword 'x' --ciuser y --sshkeys /path/pubkey
DEFAULT_USER="normal"                             # empty -> cloud image's default user "ubuntu"
DEFAULT_PASSWORD="Normal"                         # empty -> no password; set one per clone
DEFAULT_SSHKEY=""                                 # e.g. /root/.ssh/id_ed25519.pub

REFRESH_IMAGE=1                                   # 1 = always re-download latest build, 0 = reuse local
WIPE_EXISTING=1                                   # 1 = destroy an existing VM with $VMID and rebuild

# --------------------------------------------------- P R O G R A M ----------------------------------------------------

IMG_FILE="${IMG_DIR}/$(basename "${IMG_URL}")"

echo "==> Checking for required host tools"
for pkg in libguestfs-tools; do
  # virt-customize ships in libguestfs-tools; only install if missing
  command -v virt-customize >/dev/null || apt-get install -y "$pkg"
done

echo "==> Downloading cloud image (latest build)"
mkdir -p "${IMG_DIR}"
if [[ ${REFRESH_IMAGE} -eq 1 || ! -f "${IMG_FILE}" ]]; then
  wget -q --show-progress -O "${IMG_FILE}" "${IMG_URL}"
  # Optional paranoia: verify against the published checksums
  # wget -qO "${IMG_DIR}/SHA256SUMS" "${IMG_URL%/*}/SHA256SUMS"
  # (cd "${IMG_DIR}" && sha256sum -c SHA256SUMS 2>/dev/null | grep OK)
else
  echo "    Skipping download (REFRESH_IMAGE=0, ${IMG_FILE} exists)"
fi

echo "==> Customizing image"
# Two fixes baked into the image itself:
#  1. qemu-guest-agent -> Proxmox web UI can show IPs/hostname, and
#     `qm guest cmd` works. (No cicustom needed -> per-clone qm set stays usable.)
#  2. Delete the cloud image's "PasswordAuthentication no" drop-in so that
#     password SSH (via --cipassword) works on clones.
# Both operations are safe to run repeatedly (package install is a no-op).
virt-customize -a "${IMG_FILE}" \
  --install qemu-guest-agent \
  --run-command "systemctl enable qemu-guest-agent || true" \
  --delete /etc/ssh/sshd_config.d/60-cloudimg-settings.conf 2>/dev/null \
  || echo "    NOTE: sshd drop-in not found (maybe already deleted). Continuing"

echo "==> Handling existing VM with ID ${VMID}"
if qm status "${VMID}" >/dev/null 2>&1; then
  if [[ ${WIPE_EXISTING} -eq 1 ]]; then
    echo "    Destroying existing VM ${VMID} for a fresh rebuild"
    qm stop "${VMID}" >/dev/null 2>&1 || true   # stop if running; ignore if not
    qm destroy "${VMID}" --purge
  else
    echo "ERROR: VM ${VMID} already exists and WIPE_EXISTING=0" >&2
    exit 1
  fi
fi

echo "==> Creating VM ${VMID} (${TEMPLATE_NAME})"
# NOTE: virtio-scsi-pci is REQUIRED for Ubuntu cloud images (per PVE wiki).
qm create "${VMID}" \
  --name "${TEMPLATE_NAME}" \
  --memory "${MEMORY_MB}" \
  --cores "${CORES}" \
  --net0 "virtio,bridge=${BRIDGE}" \
  --scsihw virtio-scsi-pci \
  --ostype l26 \
  --agent enabled=1,fstrim_cloned_disks=1 \
  --vga virtio,memory=16 \
  --serial0 socket

echo "==> Importing disk image as root disk"
# import-from copies the qcow2 into a proper ${STORAGE} volume in one step.
# ssd=1 + discard=on lets the guest TRIM through to thin-provisioned storage.
qm set "${VMID}" \
  --scsi0 "${STORAGE}:0,import-from=${IMG_FILE},ssd=1,discard=on"

echo "==> Expanding root disk to ${ROOT_DISK_SIZE_GB}G"
qm resize "${VMID}" scsi0 "${ROOT_DISK_SIZE_GB}G"

echo "==> Adding cloud-init drive and boot config"
# ide2 = the cloud-init config CD-ROM Proxmox generates per-VM.
qm set "${VMID}" --ide2 "${STORAGE}:cloudinit"
# Boot straight from the root disk; skips BIOS probing the CD-ROM.
qm set "${VMID}" --boot order=scsi0

echo "==> Setting cloud-init defaults (DHCP only)"
qm set "${VMID}" --ipconfig0 ip=dhcp # explicit DHCP: clones always get an IP
[[ -n ${DEFAULT_USER}     ]] && qm set "${VMID}" --ciuser "${DEFAULT_USER}"
[[ -n ${DEFAULT_PASSWORD} ]] && qm set "${VMID}" --cipassword "${DEFAULT_PASSWORD}"
[[ -n ${DEFAULT_SSHKEY}   ]] && qm set "${VMID}" --sshkeys "${DEFAULT_SSHKEY}"

echo "==> Converting to template"
qm template "${VMID}"

echo
echo "✅ Template ${VMID} (${TEMPLATE_NAME}) ready."
echo "   Deploy:   qm clone ${VMID} 123 --name testvm1 && qm start 123"
echo "   Password: qm set 123 --cipassword 'whatever'   # before first start"
echo "   Get IP:   qm guest cmd 123 network-get-interfaces"