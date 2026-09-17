"""The main window.

Laid out like the WinUI 3 app on the Windows side: a navigation sidebar, a
Tools page whose entries are grouped cards, and one page per tool with its own
title, description and Run button. Tool output lands in that page rather than
in a single shared console, so switching tools never shows you the previous
tool's text.
"""

from __future__ import annotations

import threading
from collections.abc import Callable

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, GLib, Gtk, Pango  # noqa: E402

from .. import catalog, system  # noqa: E402
from ..tools import REGISTRY, Cancelled, ToolContext  # noqa: E402
from ..version import get_version  # noqa: E402
from . import dialogs  # noqa: E402

REPO_URL = "https://github.com/REALSDEALS/pcHealth"

# Category -> icon, mirroring the glyphs the WinUI 3 tool list uses.
_CATEGORY_ICONS = {
    "Information": "dialog-information-symbolic",
    "Network": "network-wired-symbolic",
    "Disk": "drive-harddisk-symbolic",
    "Updates": "software-update-available-symbolic",
    "Maintenance": "applications-engineering-symbolic",
    "Security": "security-high-symbolic",
    "Hardware": "computer-symbolic",
    "System": "system-shutdown-symbolic",
}

# Output colours, close to the terminal palette so both front-ends read alike.
_PALETTE = {
    "light": {
        "head": "#1c71d8",
        "ok": "#26794e",
        "warn": "#a35a00",
        "error": "#c01c28",
        "muted": "#5e5c64",
    },
    "dark": {
        "head": "#78aeed",
        "ok": "#8ff0a4",
        "warn": "#f8e45c",
        "error": "#ff938c",
        "muted": "#9a9996",
    },
}


class OutputView(Gtk.ScrolledWindow):
    """Read-only monospaced view that tool output is appended to."""

    def __init__(self) -> None:
        super().__init__(hexpand=True, vexpand=True)
        self._view = Gtk.TextView(
            editable=False,
            cursor_visible=False,
            monospace=True,
            wrap_mode=Gtk.WrapMode.WORD_CHAR,
            top_margin=12,
            bottom_margin=12,
            left_margin=16,
            right_margin=16,
        )
        self._buffer = self._view.get_buffer()
        self.set_child(self._view)

        dark = Adw.StyleManager.get_default().get_dark()
        for name, colour in _PALETTE["dark" if dark else "light"].items():
            weight = Pango.Weight.BOLD if name == "head" else Pango.Weight.NORMAL
            self._buffer.create_tag(name, foreground=colour, weight=weight)

    def clear(self) -> None:
        self._buffer.set_text("")

    def append(self, text: str, style: str) -> None:
        """Append one line. Safe to call from any thread."""

        def write() -> bool:
            end = self._buffer.get_end_iter()
            if self._buffer.get_tag_table().lookup(style):
                self._buffer.insert_with_tags_by_name(end, text + "\n", style)
            else:
                self._buffer.insert(end, text + "\n")
            mark = self._buffer.create_mark(None, self._buffer.get_end_iter(), False)
            self._view.scroll_mark_onscreen(mark)
            self._buffer.delete_mark(mark)
            return GLib.SOURCE_REMOVE

        GLib.idle_add(write)


class ToolPage(Adw.NavigationPage):
    """One tool: its description, a Run button, and its own output."""

    def __init__(self, tool: catalog.Tool, window: Gtk.Window) -> None:
        super().__init__(title=tool.name)
        self._tool = tool
        self._window = window
        self._worker: threading.Thread | None = None
        self._stop = threading.Event()

        self._output = OutputView()
        self._run = Gtk.Button(label="Run", css_classes=["suggested-action"])
        self._stop_button = Gtk.Button(label="Stop", sensitive=False)
        self._run.connect("clicked", self._on_run)
        self._stop_button.connect("clicked", lambda _b: self._stop.set())

        header = Adw.HeaderBar()
        header.pack_end(self._run)
        header.pack_end(self._stop_button)

        description = Gtk.Label(
            label=tool.note or f"{tool.category} tool",
            xalign=0,
            wrap=True,
            css_classes=["dim-label"],
            margin_top=12,
            margin_bottom=12,
            margin_start=16,
            margin_end=16,
        )

        body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        body.append(description)
        body.append(Gtk.Separator())
        body.append(self._output)

        view = Adw.ToolbarView()
        view.add_top_bar(header)
        view.set_content(body)
        self.set_child(view)

    def _on_run(self, _button: Gtk.Button) -> None:
        if self._worker and self._worker.is_alive():
            return
        implementation = REGISTRY.get(self._tool.id)
        if implementation is None:
            self._output.append(f"No implementation registered for '{self._tool.id}'.", "error")
            return

        self._output.clear()
        self._stop.clear()
        self._run.set_sensitive(False)
        self._stop_button.set_sensitive(True)

        context = ToolContext(
            emit=self._output.append,
            choose=lambda question, options: dialogs.choose(self._window, question, options),
            confirm=lambda question: dialogs.confirm(self._window, question),
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
                GLib.idle_add(self._finish)

        self._worker = threading.Thread(target=work, daemon=True, name=f"pchealth-{self._tool.id}")
        self._worker.start()

    def _finish(self) -> bool:
        self._stop_button.set_sensitive(False)
        self._run.set_sensitive(True)
        return GLib.SOURCE_REMOVE


def _tools_page(open_tool: Callable[[catalog.Tool], None]) -> Adw.NavigationPage:
    """The tool list, grouped by category the way the WinUI 3 page groups it."""
    page = Adw.PreferencesPage()

    # Group properly rather than starting a new heading on every change: the
    # catalogue is in menu order, so categories interleave and a naive scan
    # prints "Updates" three times.
    by_category: dict[str, list[catalog.Tool]] = {}
    for tool in catalog.active():
        by_category.setdefault(tool.category, []).append(tool)

    for category, tools in by_category.items():
        group = Adw.PreferencesGroup(title=category)
        for tool in tools:
            icon = _CATEGORY_ICONS.get(category, "application-x-executable-symbolic")
            row = Adw.ActionRow(title=tool.name, subtitle=tool.note, activatable=True)
            row.add_prefix(Gtk.Image.new_from_icon_name(icon))
            row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
            row.connect("activated", lambda _row, t=tool: open_tool(t))
            group.add(row)
        page.add(group)

    return Adw.NavigationPage(title="Tools", child=page)


def _about_page() -> Adw.NavigationPage:
    status = Adw.StatusPage(
        icon_name="utilities-system-monitor-symbolic",
        title="pcHealth",
        description=(
            f"Version {get_version()}\n\n"
            "Check the health of your Linux installation, drivers, updates and battery.\n"
            "Made by REALSDEALS — licensed under GNU GPL-3."
        ),
    )
    link = Gtk.Button(label="Open the repository", halign=Gtk.Align.CENTER, css_classes=["pill"])
    link.connect("clicked", lambda _b: system.open_url(REPO_URL))
    status.set_child(link)
    return Adw.NavigationPage(title="About", child=status)


class MainWindow(Adw.ApplicationWindow):
    def __init__(self, application: Adw.Application) -> None:
        super().__init__(
            application=application,
            title="pcHealth",
            default_width=1100,
            default_height=720,
        )

        self._content = Adw.NavigationView()
        self._pages = {
            "tools": lambda: _tools_page(self._open_tool),
            "about": _about_page,
        }

        sidebar = Gtk.ListBox(
            css_classes=["navigation-sidebar"],
            selection_mode=Gtk.SelectionMode.SINGLE,
        )
        for key, label, icon in (
            ("tools", "Tools", "applications-utilities-symbolic"),
            ("about", "About", "help-about-symbolic"),
        ):
            row = Adw.ActionRow(title=label)
            row.add_prefix(Gtk.Image.new_from_icon_name(icon))
            row.page_key = key
            sidebar.append(row)
        sidebar.connect("row-selected", self._on_nav)

        sidebar_view = Adw.ToolbarView()
        sidebar_view.add_top_bar(
            Adw.HeaderBar(
                title_widget=Adw.WindowTitle(title="pcHealth", subtitle=f"v{get_version()}"),
                show_end_title_buttons=False,
            )
        )
        sidebar_view.set_content(Gtk.ScrolledWindow(child=sidebar, vexpand=True))
        # Said once, at the bottom, rather than crowding the window controls.
        if not system.is_root():
            sidebar_view.add_bottom_bar(
                Gtk.Label(
                    label="Each action asks for elevation",
                    css_classes=["dim-label", "caption"],
                    margin_top=8,
                    margin_bottom=8,
                )
            )

        self.set_content(
            Adw.NavigationSplitView(
                sidebar=Adw.NavigationPage(title="pcHealth", child=sidebar_view),
                content=Adw.NavigationPage(title="pcHealth", child=self._content),
                min_sidebar_width=240,
            )
        )

        sidebar.select_row(sidebar.get_row_at_index(0))

    def _on_nav(self, _list: Gtk.ListBox, row: Gtk.ListBoxRow | None) -> None:
        key = getattr(row, "page_key", None)
        if key is None:
            return
        self._content.replace([self._pages[key]()])

    def _open_tool(self, tool: catalog.Tool) -> None:
        self._content.push(ToolPage(tool, self))
