"""GTK4 / libadwaita front-end.

The window runs unprivileged on purpose. A root-owned GUI cannot reach the
user's Wayland session without loosening the display's own access control, and
a toolkit running as root is a bad idea regardless. Privilege is raised per
action through pkexec instead -- see system.elevated().
"""

from __future__ import annotations

import sys

APP_ID = "nl.realsdeals.pcHealth"

_MISSING_GTK = """pcHealth GUI needs PyGObject with GTK 4 and libadwaita.

Install it with your package manager:
  Fedora / RHEL:     dnf install python3-gobject gtk4 libadwaita
  Debian / Ubuntu:   apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1
  Arch / CachyOS:    pacman -S python-gobject gtk4 libadwaita
  openSUSE:          zypper install python3-gobject gtk4 libadwaita

The terminal version needs none of this -- run: pchealth
"""


def main() -> int:
    if sys.platform != "linux":
        print("pcHealth GUI runs on Linux only.", file=sys.stderr)
        return 1

    try:
        import gi

        gi.require_version("Gtk", "4.0")
        gi.require_version("Adw", "1")
        from gi.repository import Adw
    except (ImportError, ValueError):
        print(_MISSING_GTK, file=sys.stderr)
        return 1

    from .window import MainWindow

    class PcHealthApplication(Adw.Application):
        def __init__(self) -> None:
            super().__init__(application_id=APP_ID)

        def do_activate(self) -> None:
            window = self.props.active_window or MainWindow(self)
            window.present()

    return PcHealthApplication().run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
