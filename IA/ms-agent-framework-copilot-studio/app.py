import asyncio
import json
import sys
from datetime import datetime
from pathlib import Path

# Force UTF-8 no stdout antes de qualquer import que escreva no terminal
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

from dotenv import load_dotenv
from rich.console import Console, group
from rich.live import Live
from rich.markdown import Markdown
from rich.panel import Panel
from rich.spinner import Spinner
from rich.text import Text

from core.config import build_direct_line_runtime_config
from core.logging_config import configure_logging
from core.router import AgentRouter

# force_terminal=True: usa ANSI/VT ao invés do Win32 legacy API (evita cp1252)
console = Console(force_terminal=True, emoji=True)

STATUS_STYLE: dict[str, tuple[str, str]] = {
    "completed": ("green",  "✓"),
    "timeout":   ("yellow", "…"),
    "failed":    ("red",    "✗"),
}

HELP_TEXT = """\
/help       show commands
/status     show current session state
/agents     show registered agents and environments
/debug      show raw responses returned by sub-agents
/activities show raw Direct Line activities captured per agent
/timeline   show agent timeline for the current session
/reset      reset current session context
/session X  switch to another session id
/exit       finish chat
"""

load_dotenv(dotenv_path=Path(__file__).with_name(".env"))
RUNTIME_CONFIG = build_direct_line_runtime_config()
configure_logging(
    debug_mode=RUNTIME_CONFIG.debug_mode,
    structured=RUNTIME_CONFIG.structured_logging,
)


# ── Layout ────────────────────────────────────────────────────────────────────

def _print_header(session_id: str) -> None:
    debug_flag = "on" if RUNTIME_CONFIG.debug_mode else "off"
    console.print()
    console.print(Panel(
        f"[dim]session:[/] {session_id}   [dim]debug:[/] {debug_flag}",
        title="[bold cyan]MS Agent Framework[/]",
        border_style="cyan",
        padding=(0, 2),
    ))
    console.print("  [dim]Commands:[/]  [dim cyan]/help  ·  /agents  ·  /timeline  ·  /reset  ·  /exit[/]\n")


def _print_divider() -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    console.print()
    console.rule(f"[dim cyan]{ts}[/]", style="dim cyan")
    console.print()


def _print_supervisor(text: str) -> None:
    console.print("[bold green]Supervisor[/]")
    console.print(Markdown(text))
    _print_divider()


def _print_agent_timeline(events: list[dict]) -> None:
    if not events:
        return
    console.print("[bold yellow]Agent Timeline[/]")
    for e in events:
        if e["status"] == "started":
            console.print(f"  [dim]·[/] [bold cyan]{e['agent_key']}[/]  [dim]calling[/]")
        else:
            style, icon = STATUS_STYLE.get(e["status"], ("dim", "·"))
            console.print(f"  [{style}]{icon}[/] [bold cyan]{e['agent_key']}[/]  [dim]{e['status']}[/]")
            if e["response_preview"]:
                console.print(f"      [dim]{e['response_preview']}[/]")
    console.print()


def _print_registered_agents(snapshot: dict) -> None:
    console.print("[bold cyan]Registered Agents[/]")
    for key, info in snapshot["registered_agents"].items():
        console.print(f"  [dim]·[/] {key}: {info['name']} [[dim]{info['department']}[/]]")
    console.print()


# ── Live agent activity stream ────────────────────────────────────────────────
#
# Composição via @group() decorator do Rich:
#   - locked → Text renderables já permanentes (completed/failed/timeout)
#   - active_key → Spinner animado pelo Live (calling...)
#   - no_events → Spinner genérico enquanto o LLM ainda não chamou nenhum agente

def _activity_renderable(locked: list[Text], active_key: str | None, no_events: bool):
    @group()
    def _render():
        yield from locked
        if active_key:
            yield Spinner(
                "dots",
                text=Text.from_markup(f"  [bold cyan]{active_key}[/]  [dim]calling[/]"),
            )
        elif no_events:
            yield Spinner("dots", text=Text.from_markup("  [dim]orchestrating[/]"))

    return _render()


async def _stream_agent_activity(task: asyncio.Task, session_reader, start_index: int) -> None:
    seen = 0
    active_key: str | None = None
    locked: list[Text] = []

    def _drain(events: list[dict]) -> None:
        nonlocal seen, active_key
        for event in events[seen:]:
            if event["status"] == "started":
                active_key = event["agent_key"]
            else:
                style, icon = STATUS_STYLE.get(event["status"], ("dim", "·"))
                locked.append(Text.from_markup(
                    f"  [{style}]{icon}[/] [bold cyan]{event['agent_key']}[/]  [dim]{event['status']}[/]"
                ))
                active_key = None
            seen += 1

    # auto_refresh=False: sem thread de background — compatível com asyncio
    with Live(console=console, auto_refresh=False, transient=False) as live:
        while not task.done():
            _drain(session_reader()["tool_events"][start_index:])
            live.update(_activity_renderable(locked, active_key, no_events=(seen == 0)))
            live.refresh()
            await asyncio.sleep(0.1)

        # Drena eventos que chegaram exatamente ao final da task
        _drain(session_reader()["tool_events"][start_index:])
        active_key = None
        live.update(_activity_renderable(locked, active_key, no_events=(seen == 0)))
        live.refresh()

    console.print()


# ── Main loop ─────────────────────────────────────────────────────────────────

async def interactive_chat() -> None:
    router = AgentRouter()
    session_id = "local-console"

    _print_header(session_id)

    while True:
        user_input = console.input("\n[bold white]You[/] › ").strip()
        if not user_input:
            continue

        if user_input.lower() in {"exit", "quit", "/exit"}:
            break
        if user_input == "/help":
            console.print(HELP_TEXT)
            continue
        if user_input == "/status":
            console.print_json(json.dumps(router.describe_session(session_id), ensure_ascii=False))
            continue
        if user_input == "/agents":
            _print_registered_agents(router.describe_session(session_id))
            continue
        if user_input == "/debug":
            console.print_json(json.dumps(
                router.describe_session(session_id)["last_agent_responses"],
                ensure_ascii=False,
            ))
            continue
        if user_input == "/activities":
            snapshot = router.describe_session(session_id)
            activities = {k: v["last_raw_activities"] for k, v in snapshot["copilot_conversations"].items()}
            console.print_json(json.dumps(activities, ensure_ascii=False))
            continue
        if user_input == "/timeline":
            _print_agent_timeline(router.describe_session(session_id)["tool_events"])
            continue
        if user_input == "/reset":
            router.reset_session(session_id)
            console.print(f"\n[bold yellow]Session Reset[/]  {session_id}\n")
            continue
        if user_input.startswith("/session "):
            new_id = user_input.removeprefix("/session ").strip()
            if not new_id:
                console.print("\nProvide a session id after /session.\n")
                continue
            session_id = new_id
            router.get_or_create_session(session_id)
            console.print(f"\n[bold cyan]Active Session[/]  {session_id}\n")
            continue

        before = len(router.describe_session(session_id)["tool_events"])

        response_task = asyncio.create_task(router.route_and_process(user_input, session_id=session_id))
        stream_task = asyncio.create_task(
            _stream_agent_activity(response_task, lambda: router.describe_session(session_id), before)
        )

        response = await response_task
        await stream_task

        if RUNTIME_CONFIG.debug_mode:
            _print_agent_timeline(router.describe_session(session_id)["tool_events"][before:])

        _print_supervisor(response)


if __name__ == "__main__":
    asyncio.run(interactive_chat())
