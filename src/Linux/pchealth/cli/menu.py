"""The terminal menus."""

from __future__ import annotations

from collections.abc import Sequence

from .. import catalog, system
from ..tools import REGISTRY, Cancelled, Choice, ToolContext
from ..version import get_version
from . import programs, theme

REPO_URL = "https://github.com/REALSDEALS/pcHealth"
RELEASES_URL = f"{REPO_URL}/releases"


def _terminal_context() -> ToolContext:
    def prompt(text: str) -> str:
        try:
            return input(f"  {text}: ")
        except EOFError as exc:
            raise Cancelled("no input available") from exc

    def choose(question: str, options: Sequence[Choice]) -> str | None:
        while True:
            theme.write()
            for index, option in enumerate(options, start=1):
                theme.option(str(index), option.label, option.detail)
            theme.option("B", "Back")
            theme.write()

            answer = prompt(question).strip()
            if answer.upper() == "B":
                return None
            if answer.isdigit() and 1 <= int(answer) <= len(options):
                return options[int(answer) - 1].key
            theme.write("Invalid choice.", "error")

    def confirm(question: str) -> bool:
        return prompt(f"{question} (y/n)").strip().lower() in ("y", "yes")

    return ToolContext(emit=theme.write, choose=choose, confirm=confirm)


def _run_tool(tool: catalog.Tool) -> None:
    # The tool prints its own heading, so the menu only clears the screen --
    # printing the name here as well would show it twice.
    theme.clear()
    theme.write("  pcHealth", "muted")
    theme.write()
    implementation = REGISTRY.get(tool.id)
    if implementation is None:
        theme.write(f"No implementation registered for '{tool.id}'.", "error")
        return
    try:
        implementation(_terminal_context())
    except Cancelled:
        theme.write()
        theme.write("Cancelled.", "muted")
    except KeyboardInterrupt:
        theme.write()
        theme.write("Stopped.", "muted")
    except OSError as exc:
        theme.write()
        theme.write(f"[!!] Tool error: {exc}", "error")


def _tools_menu() -> str:
    tools = catalog.active()

    while True:
        theme.header("Tools")
        for index, tool in enumerate(tools, start=1):
            theme.option(str(index), tool.name, tool.note)

        theme.write()
        nav_programs = len(tools) + 1
        nav_main = len(tools) + 2
        nav_exit = len(tools) + 3
        theme.option(str(nav_programs), "Programs Menu")
        theme.option(str(nav_main), "Back to Main Menu")
        theme.option(str(nav_exit), "Exit")
        theme.write()

        choice = input("  Choice: ").strip()
        if not choice.isdigit():
            theme.write("Invalid choice.", "error")
            continue

        number = int(choice)
        if number == nav_programs:
            return "programs"
        if number == nav_main:
            return "main"
        if number == nav_exit:
            return "exit"
        if 1 <= number <= len(tools):
            _run_tool(tools[number - 1])
            theme.write()
            nav = input("  [1] Back to Tools  [2] Main Menu  [3] Exit: ").strip()
            if nav == "2":
                return "main"
            if nav == "3":
                return "exit"
            continue

        theme.write("Invalid choice.", "error")


def _main_menu() -> str:
    theme.header("Main Menu", f"Linux  --  v{get_version()}")

    theme.write("  Thanks for downloading and using pcHealth!")
    theme.write("  Made by REALSDEALS - Licensed under GNU-3", "muted")
    theme.write()

    if not system.is_root():
        theme.write("  Not running as root -- each action will ask for elevation.", "warn")
        theme.write("  Run `sudo pchealth` to be asked once instead.", "muted")
        theme.write()

    theme.option("1", "Tools")
    theme.option("2", "Programs")
    theme.write()
    theme.option("3", "Go to repository")
    theme.option("4", "Check for pre-releases")
    theme.write()
    theme.option("5", "Exit")
    theme.write()

    choice = input("  Choice: ").strip()
    if choice == "1":
        return "tools"
    if choice == "2":
        return "programs"
    if choice == "3":
        system.open_url(REPO_URL)
        return "main"
    if choice == "4":
        system.open_url(RELEASES_URL)
        return "main"
    if choice == "5":
        return "exit"

    theme.write("Invalid choice.", "error")
    return "main"


def run() -> int:
    target = "main"
    while True:
        try:
            if target == "tools":
                target = _tools_menu()
            elif target == "programs":
                target = programs.show()
            elif target == "exit":
                theme.write()
                theme.write("  Goodbye.", "muted")
                return 0
            else:
                target = _main_menu()
        except (KeyboardInterrupt, EOFError):
            theme.write()
            theme.write("  Goodbye.", "muted")
            return 0
