import subprocess
from argparse import Namespace


class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        action = "deleteHistory" if self.args.delete else "open"
        raise SystemExit(subprocess.run(["qs", "-c", "devine", "ipc", "call", "clipboard", action]).returncode)
