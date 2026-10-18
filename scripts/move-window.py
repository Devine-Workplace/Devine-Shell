#!/usr/bin/env python3
"""Move an exact window while preserving every monitor's visible desktop."""
import json
import datetime
import shutil
import subprocess
import sys
import os
from pathlib import Path


def query(name):
    return json.loads(subprocess.check_output(["hyprctl", name, "-j"]))


def dispatch(expression):
    result = subprocess.run(["hyprctl", "dispatch", expression], text=True, capture_output=True)
    if result.returncode or result.stdout.strip() != "ok":
        raise RuntimeError(result.stdout.strip() or result.stderr.strip())


def selector(workspace):
    name = workspace.get("name", "")
    return name if name.startswith("special:") else "name:" + name if workspace["id"] < 0 else str(workspace["id"])


try:
    address, destination = sys.argv[1:3]
    clients = query("clients")
    window = next((window for window in clients if window["address"] == address), None)
    if window is None:
        raise RuntimeError("This window has already closed.")
    if selector(window["workspace"]) == destination:
        print("ok")
        sys.exit(0)
    source = next((workspace for workspace in query("workspaces") if workspace["id"] == window["workspace"]["id"]), None)
    if source and not source.get("ispersistent") and not source["name"].startswith("special:"):
        config = Path.home() / ".config/hypr/config/workspaces.lua"
        backup = Path(os.environ.get('XDG_STATE_HOME', str(Path.home()/'.local/state'))) / 'devine/backups' / ("before-preserving-drag-source-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
        backup.mkdir(parents=True)
        shutil.copy2(config, backup / config.name)
        with config.open("a") as file:
            file.write("\n-- Preserve desktops when their last window is moved\nhl.workspace_rule({ workspace = " + json.dumps(selector(source)) + ", monitor = " + json.dumps(source["monitor"]) + ", persistent = true })\n")
        subprocess.run(["hyprctl", "reload"], check=True, capture_output=True)
    monitors = query("monitors")
    focused = next((monitor["name"] for monitor in monitors if monitor.get("focused")), None)
    dispatch("hl.dsp.window.move({workspace=" + json.dumps(destination) + ",window=" + json.dumps("address:" + address) + ",follow=false})")
    after = {monitor["name"]: monitor for monitor in query("monitors")}
    for monitor in monitors:
        current = after.get(monitor["name"])
        if current and current["activeWorkspace"]["id"] != monitor["activeWorkspace"]["id"]:
            dispatch("hl.dsp.focus({monitor=" + json.dumps(monitor["name"]) + "})")
            dispatch("hl.dsp.focus({workspace=" + json.dumps(selector(monitor["activeWorkspace"])) + "})")
    if focused and next((m["name"] for m in query("monitors") if m.get("focused")), None) != focused:
        dispatch("hl.dsp.focus({monitor=" + json.dumps(focused) + "})")
    print("ok")
except Exception as error:
    print(str(error))
    sys.exit(1)
