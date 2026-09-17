"""Dialogs a tool can ask for from its worker thread.

A tool runs off the main loop, but GTK may only be touched from it. Each helper
therefore hops to the main loop, shows the dialog, and blocks the worker on an
Event until the answer comes back.
"""

from __future__ import annotations

import threading
from typing import Any

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk  # noqa: E402

# Adw.AlertDialog arrived in libadwaita 1.5 and replaced Adw.MessageDialog.
# Distros ship both, so pick whichever this system actually has.
_ALERT = getattr(Adw, "AlertDialog", None) or Adw.MessageDialog
_USES_ALERT_DIALOG = hasattr(Adw, "AlertDialog")


def _present(dialog: Any, parent: Gtk.Window) -> None:
    if _USES_ALERT_DIALOG:
        dialog.present(parent)
    else:
        dialog.set_transient_for(parent)
        dialog.present()


def confirm(parent: Gtk.Window, question: str) -> bool:
    """Ask a yes/no question from a worker thread and wait for the answer."""
    done = threading.Event()
    answer = False

    def build() -> bool:
        dialog = _ALERT(heading="pcHealth", body=question)
        dialog.add_response("no", "Cancel")
        dialog.add_response("yes", "Continue")
        dialog.set_response_appearance("yes", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("no")
        dialog.set_close_response("no")

        def on_response(_dialog: Any, response: str) -> None:
            nonlocal answer
            answer = response == "yes"
            done.set()

        dialog.connect("response", on_response)
        _present(dialog, parent)
        return GLib.SOURCE_REMOVE

    GLib.idle_add(build)
    done.wait()
    return answer


def ask(parent: Gtk.Window, prompt: str) -> str:
    """Ask for a line of text from a worker thread and wait for the answer."""
    done = threading.Event()
    answer = ""

    def build() -> bool:
        entry = Gtk.Entry(activates_default=True)
        dialog = _ALERT(heading="pcHealth", body=prompt)
        dialog.set_extra_child(entry)
        dialog.add_response("cancel", "Cancel")
        dialog.add_response("ok", "OK")
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("ok")
        dialog.set_close_response("cancel")

        def on_response(_dialog: Any, response: str) -> None:
            nonlocal answer
            answer = entry.get_text() if response == "ok" else ""
            done.set()

        dialog.connect("response", on_response)
        _present(dialog, parent)
        return GLib.SOURCE_REMOVE

    GLib.idle_add(build)
    done.wait()
    return answer
