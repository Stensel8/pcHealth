"""What a tool is.

A tool never talks to the terminal or to GTK directly. It emits styled lines
and asks questions through the context it is handed, so the same tool runs
under the CLI menu and inside the GUI without knowing which one it is in.
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


def _never() -> bool:
    return False


@dataclass(frozen=True)
class ToolContext:
    emit: Callable[[str, Style], None]
    ask: Callable[[str], str]
    confirm: Callable[[str], bool]
    # Long-running tools poll this so a GUI can stop a continuous ping without
    # the tool knowing a GUI exists. The CLI leaves it at the default and lets
    # Ctrl+C do the same job.
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


# A tool is just a function over a context. The return value is unused: what
# the user sees is what the tool emitted.
ToolFunc = Callable[[ToolContext], None]
