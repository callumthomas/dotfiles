# Suspend-then-Hibernate Setup

ThinkPad P14s Gen 6 AMD on Arch Linux.

Only s2idle is available on this hardware — S3/deep sleep is not supported.
Do NOT attempt to force S3 via BIOS — it can brick the firmware.

s2idle still draws power, so suspend-then-hibernate is the way to go:
suspend for quick wake, then hibernate to zero power after a timeout.

## Prerequisites

- LUKS-encrypted root on `/dev/mapper/root` (ext4)
- systemd-boot
- Hyprland with hyprlock and hypridle (configured separately)

## 1. Create swap file

zram is RAM-backed and can't be used for hibernation. Need a real swap file on disk.

```bash
sudo dd if=/dev/zero of=/swapfile bs=1G count=32 status=progress
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 2. Add swap to fstab

```bash
echo '/swapfile none swap defaults 0 0' | sudo tee -a /etc/fstab
```

## 3. Get the swap file offset

```bash
sudo filefrag -v /swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'
```

Note the number — needed for the bootloader entry.

## 4. Add resume parameters to systemd-boot

Edit `/boot/loader/entries/<your-entry>.conf` and append to the `options` line:

```
resume=/dev/mapper/root resume_offset=<NUMBER_FROM_STEP_3>
```

Full example:

```
options cryptdevice=PARTUUID=... root=/dev/mapper/root zswap.enabled=0 rw rootfstype=ext4 resume=/dev/mapper/root resume_offset=12345678
```

## 5. Add resume hook to initramfs

Edit `/etc/mkinitcpio.conf` and add `resume` between `filesystems` and `fsck`:

```
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems resume fsck)
```

Then regenerate:

```bash
sudo mkinitcpio -P
```

## 6. Configure suspend-then-hibernate

```bash
sudo mkdir -p /etc/systemd/sleep.conf.d
```

Create `/etc/systemd/sleep.conf.d/suspend-then-hibernate.conf`:

```ini
[Sleep]
HibernateDelaySec=1800
```

1800 = 30 minutes in s2idle before hibernating. Adjust to taste.

## 7. Set logind to ignore lid switch

Hyprland handles the lid switch via a bind, so logind should not interfere.

In `/etc/systemd/logind.conf`:

```ini
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
```

Then either reboot or `sudo systemctl restart systemd-logind` (will kill your session).

## 8. Reboot and test

```bash
sudo reboot
```

Test in order:

1. `systemctl hibernate` — should power off, resume on power button press
2. `systemctl suspend-then-hibernate` — should suspend, then hibernate after 30 min
3. Close the lid — should lock (hyprlock) then suspend-then-hibernate

If hibernate fails, check `journalctl -b -1 | grep -i hibern` for errors.
