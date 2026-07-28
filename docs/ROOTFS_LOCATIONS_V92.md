# RootFS Locations — v9.2

The v9.2 location API centralizes destination selection for all RootFS builders.

## Standard locations

- `/AOK/roots`
- `/opt/AOK/roots`
- `/root`

## Safety rules

Destinations must be absolute. Critical paths such as `/`, `/AOK`, `/opt/AOK`, `/root`, `/home`, `/usr`, `/var`, and `/etc` cannot be selected as a RootFS destination. Existing non-empty directories require explicit confirmation.

## Integration

The API is used by guided profiles, recipes, staged builds, debootstrap, APK, pacstrap, DNF/YUM installroot, XBPS installroot, and directory imports. Recent successful selections are stored in the application state directory.
