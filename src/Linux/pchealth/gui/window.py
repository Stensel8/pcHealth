"""The main window: tool list on the left, tool output on the right."""

from __future__ import annotations

import threading

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk, Pango  # noqa: E402

from .. import catalog, system  # noqa: E402
from ..tools import REGISTRY, Cancelled, ToolContext  # noqa: E402
from ..version import get_version  # noqa: E402
from . import dialogs  # noqa: E402

# Style name -> text colour. Kept close to the terminal palette so the two
# front-ends read the same, and defined per theme so it stays legible in both.
_COLOURS_LIGHT = {
    "head": "#1c71d8",
    "ok": "#26794e",
    "warn": "#a35a00",
    "error": "#c01c28",
    "muted": "#5e5c64",
}
_COLOURS_DARK = {
    "head": "#78aeed",
    "ok": "#8ff0a4",
    "warn": "#f8e45c",
    "error": "#ff938c",
    "muted": "#9a9996",
}


class TerminalView(Gtk.ScrolledWindow):
    """A read-only, monospaced text view that tool output is appended to."""

    def __init__(self) -> None:
        super().__init__(hexpand=True, vexpand=True)
        self._view = Gtk.TextView(
            editable=False,
            cursor_visible=False,
            monospace=True,
            wrap_mode=Gtk.WrapMode.WORD_CHAR,
            top_margin=12,
            bottom_margin=12,
            left_margin=12,
            right_margin=12,
        )
        self._buffer = self._view.get_buffer()
        self.set_child(self._view)

        dark = Adw.StyleManager.get_default().get_dark()
        palette = _COLOURS_DARK if dark else _COLOURS_LIGHT
        for name, colour in palette.items():
            weight = Pango.Weight.BOLD if name == "head" else Pango.Weight.NORMAL
            self._buffer.create_tag(name, foreground=colour, weight=weight)

    def clear(self) -> None:
        self._buffer.set_text("")

    def append(self, text: str, style: str) -> None:
        """Append one line. Safe to call from any thread."""

        def write() -> bool:
            end = self._buffer.get_end_iter()
            if style in ("head", "ok", "warn", "error", "muted"):
                self._buffer.insert_with_tags_by_name(end, text + "\n", style)
            else:
                self._buffer.insert(end, text + "\n")
            # Keep the newest line in view without stealing focus.
            mark = self._buffer.create_mark(None, self._buffer.get_end_iter(), False)
            self._view.scroll_mark_onscreen(mark)
            self._buffer.delete_mark(mark)
            return GLib.SOURCE_REMOVE

        GLib.idle_add(write)


class MainWindow(Adw.ApplicationWindow):
    def __init__(self, application: Adw.Application) -> None:
        super().__init__(
            application=application, title="pcHealth", default_width=1100, default_height=720
        )

        self._worker: threading.Thread | None = None
        self._stop = threading.Event()

        self._output = TerminalView()
        self._run_button = Gtk.Button(
            label="Run", css_classes=["suggested-action"], sensitive=False
        )
        self._stop_button = Gtk.Button(label="Stop", sensitive=False)
        self._status = Gtk.Label(label="Select a tool", xalign=0, css_classes=["dim-label"])
        self._list = Gtk.ListBox(css_classes=["navigation-sidebar"])

        self._tools = catalog.active()
        self._build_ui()

    # -- Layout ---------------------------------------------------------------

    def _build_ui(self) -> None:
        self._list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self._list.connect("row-selected", self._on_tool_selected)

        current_category = ""
        for tool in self._tools:
            if tool.category != current_category:
                current_category = tool.category
                header = Gtk.Label(
                    label=tool.category.upper(),
                    xalign=0,
                    css_classes=["dim-label", "caption-heading"],
                    margin_top=12,
                    margin_start=12,
                    margin_bottom=4,
                )
                row = Gtk.ListBoxRow(child=header, selectable=False, activatable=False)
                self._list.append(row)

            row = Gtk.ListBoxRow()
            # GTK rows carry no payload of their own, so the tool rides along.
            row.tool = tool
            box = Gtk.Box(
                orientation=Gtk.Orientation.VERTICAL,
                spacing=2,
                margin_top=8,
                margin_bottom=8,
                margin_start=12,
                margin_end=12,
            )
            box.append(Gtk.Label(label=tool.name, xalign=0))
            if tool.note:
                box.append(
                    Gtk.Label(label=tool.note, xalign=0, css_classes=["dim-label", "caption"])
                )
            row.set_child(box)
            self._list.append(row)

        sidebar_scroll = Gtk.ScrolledWindow(child=self._list, width_request=260, vexpand=True)

        sidebar = Adw.ToolbarView()
        sidebar.add_top_bar(
            Adw.HeaderBar(
                title_widget=Adw.WindowTitle(title="pcHealth", subtitle=f"v{get_version()}")
            )
        )
        sidebar.set_content(sidebar_scroll)

        self._run_button.connect("clicked", self._on_run)
        self._stop_button.connect("clicked", self._on_stop)

        actions = Gtk.Box(
            orientation=Gtk.Orientation.HORIZONTAL,
            spacing=6,
            margin_top=6,
            margin_bottom=6,
            margin_start=12,
            margin_end=12,
        )
        actions.append(self._status)
        actions.append(Gtk.Box(hexpand=True))
        actions.append(self._stop_button)
        actions.append(self._run_button)

        content_header = Adw.HeaderBar()
        if not system.is_root():
            # Elevation happens per action through pkexec, so say so once here
            # rather than refusing to start.
            content_header.pack_end(
                Gtk.Label(label="Actions ask for elevation", css_classes=["dim-label", "caption"])
            )

        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content_box.append(actions)
        content_box.append(Gtk.Separator())
        content_box.append(self._output)

        content = Adw.ToolbarView()
        content.add_top_bar(content_header)
        content.set_content(content_box)

        split = Adw.NavigationSplitView(
            sidebar=Adw.NavigationPage(child=sidebar, title="Tools"),
            content=Adw.NavigationPage(child=content, title="Output"),
        )
        self.set_content(split)

    # -- Running a tool -------------------------------------------------------

    def _selected_tool(self) -> catalog.Tool | None:
        row = self._list.get_selected_row()
        return getattr(row, "tool", None) if row else None

    def _on_tool_selected(self, _list: Gtk.ListBox, _row: Gtk.ListBoxRow | None) -> None:
        tool = self._selected_tool()
        running = self._worker is not None and self._worker.is_alive()
        self._run_button.set_sensitive(tool is not None and not running)
        if tool:
            self._status.set_label(tool.label)

    def _on_stop(self, _button: Gtk.Button) -> None:
        self._stop.set()
        self._status.set_label("Stopping...")

    def _on_run(self, _button: Gtk.Button) -> None:
        tool = self._selected_tool()
        if tool is None or (self._worker and self._worker.is_alive()):
            return

        implementation = REGISTRY.get(tool.id)
        if implementation is None:
            self._output.append(f"No implementation registered for '{tool.id}'.", "error")
            return

        self._output.clear()
        self._stop.clear()
        self._run_button.set_sensitive(False)
        self._stop_button.set_sensitive(True)
        self._status.set_label(f"Running {tool.name}...")

        context = ToolContext(
            emit=self._output.append,
            ask=lambda prompt: dialogs.ask(self, prompt),
            confirm=lambda prompt: dialogs.confirm(self, prompt),
            should_stop=self._stop.is_set,
        )

        def work() -> None:
            try:
                implementation(context)
            except Cancelled:
                self._output.append("Cancelled.", "muted")
            except OSError as exc:
                self._output.append(f"[!!] Tool error: {exc}", "error")
            finally:
                GLib.idle_add(self._finish, tool.name)

        self._worker = threading.Thread(target=work, daemon=True, name=f"pchealth-{tool.id}")
        self._worker.start()

    def _finish(self, name: str) -> bool:
        self._stop_button.set_sensitive(False)
        self._run_button.set_sensitive(self._selected_tool() is not None)
        self._status.set_label(f"{name} finished")
        return GLib.SOURCE_REMOVE
