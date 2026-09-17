"""What a tool is.

A tool never talks to the terminal or to GTK, and it never renders a menu of
its own. It emits styled lines and it *declares* the choices it needs; each
front-end presents those its own way -- a numbered list in the terminal, real
buttons in the GUI. That is what keeps the two from drifting into each other:
the moment a tool prints "[1] ... [2] ...", it has decided it lives in a
terminal, and the GUI is stuck rendering a text box for it.
"""

from __future__ import annotations

from collections.abc import Callable, Sequence
from dataclasses import dataclass

# head  -- section heading
# info  -- ordinary text
# ok    -- something succeeded
# warn  -- something the user should read before continuing
# error -- something failed
# muted -- detail, command output, footnotes
Style = str


class Cancelled(Exception):
    """Raised when the user backs out of a prompt. Never an error."""


@dataclass(frozen=True)
class Choice:
    """One option a tool offers. `key` is what the terminal user types."""

    key: str
    label: str
    detail: str = ""
    # Marks an option that reboots, reinstalls or otherwise cannot be undone,
    # so a front-end can style it as destructive.
    destructive: bool = False


def _never() -> bool:
    return False


@dataclass(frozen=True)
class ToolContext:
    emit: Callable[[str, Style], None]
    # Returns the chosen key, or None when the user backed out.
    choose: Callable[[str, Sequence[Choice]], str | None]
    confirm: Callable[[str], bool]
    # Long-running tools poll this so a GUI can stop a continuous ping without
    # the tool knowing a GUI exists. The CLI lets Ctrl+C do the same job.
    should_stop: Callable[[], bool] = _never

    def line(self, text: str = "", style: Style = "info") -> None:
        self.emit(text, style)

    def heading(self, title: str) -> None:
        self.emit(title, "head")

    def rows(self, pairs: Sequence[tuple[str, str]], style: Style = "info") -> None:
        """Print a label/value block with the values lined up."""
        if not pairs:
            return
        width = max(len(label) for label, _ in pairs)
        for label, value in pairs:
            self.emit(f"{label.ljust(width)}  {value}", style)

    def command_output(self, rc: int, *, ok: str, failed: str | None = None) -> None:
        if rc == 0:
            self.emit(ok, "ok")
        else:
            self.emit(failed or f"Exit code {rc}.", "error")

    def cancelled(self) -> None:
        self.emit("Cancelled.", "muted")


# A tool is just a function over a context. The return value is unused: what
# the user sees is what the tool emitted.
ToolFunc = Callable[[ToolContext], None]
