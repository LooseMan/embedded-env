#!/usr/bin/env python3
"""Terraform と Ansible のローカル実行ヘルパー。"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TF_DIR = ROOT / "terraform" / "simple-libvirt-vm"
ANSIBLE_DIR = ROOT / "ansible"
INVENTORY = ANSIBLE_DIR / "inventory" / "applied_hosts.yml"
PLAYBOOK = ANSIBLE_DIR / "playbook" / "site.yml"


def run(command: list[str], *, cwd: Path = ROOT) -> subprocess.CompletedProcess[str]:
    """コマンドを表示して実行する。"""
    print(f"+ {' '.join(command)}", flush=True)
    return subprocess.run(command, cwd=cwd, check=True, text=True)


def terraform_output() -> dict:
    result = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=TF_DIR,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def connection_from_output(outputs: dict) -> dict:
    """現在の output 名と、移行後の output 名の両方に対応する。"""
    for name in ("ansible_host", "vm_connection", "test"):
        output = outputs.get(name)
        if output is None:
            continue

        value = output.get("value", output)
        if {"name", "ipv4_address"} <= value.keys():
            return {
                "group": value.get("group", "alma9"),
                "name": value["name"],
                "ip": value["ipv4_address"],
            }
        if {"host", "ip"} <= value.keys():
            return {
                "group": value.get("group", "alma9"),
                "name": value["host"],
                "ip": value["ip"],
            }

    raise RuntimeError(
        "Terraform output に Ansible 用の接続情報がありません。"
        " ansible_host、vm_connection、または test を確認してください。"
    )


def inventory_text(connection: dict) -> str:
    group = str(connection["group"])
    host = str(connection["name"]).replace("-", "_")
    ip = str(connection["ip"])
    return (
        "---\n"
        "all:\n"
        "  children:\n"
        f"    {group}:\n"
        "      hosts:\n"
        f"        {host}:\n"
        f"          ansible_host: {ip}\n"
    )


def provision(_: argparse.Namespace) -> None:
    run(["terraform", "apply", "-auto-approve"], cwd=TF_DIR)


def write_inventory(_: argparse.Namespace) -> None:
    connection = connection_from_output(terraform_output())
    INVENTORY.parent.mkdir(parents=True, exist_ok=True)
    INVENTORY.write_text(inventory_text(connection), encoding="utf-8")
    print(f"Generated {INVENTORY.relative_to(ROOT)} for {connection['name']} ({connection['ip']})")


def configure(_: argparse.Namespace) -> None:
    run(
        [
            "ansible-playbook",
            "-i",
            str(INVENTORY),
            str(PLAYBOOK),
            "--ask-become-pass",
        ],
        cwd=ANSIBLE_DIR,
    )


def clean(_: argparse.Namespace) -> None:
    run(["terraform", "destroy", "-auto-approve"], cwd=TF_DIR)
    if INVENTORY.exists():
        INVENTORY.unlink()
        print(f"Removed {INVENTORY.relative_to(ROOT)}")


def build(args: argparse.Namespace) -> None:
    provision(args)
    write_inventory(args)
    configure(args)


def parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    for name, function in (
        ("build", build),
        ("provision", provision),
        ("inventory", write_inventory),
        ("configure", configure),
        ("clean", clean),
    ):
        subparser = subparsers.add_parser(name)
        subparser.set_defaults(function=function)

    return parser


def main() -> int:
    args = parser().parse_args()
    try:
        args.function(args)
    except subprocess.CalledProcessError as error:
        return error.returncode or 1
    except (json.JSONDecodeError, RuntimeError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
