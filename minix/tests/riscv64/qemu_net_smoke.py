#!/usr/bin/env python3
"""
QEMU VirtIO-net + lwIP smoke test for MINIX/riscv64.

Boots with user networking, requires virtio-net-mmio init, then checks
ifconfig vio0, ping6 ::1, and ping of the SLIRP gateway.
"""

from __future__ import annotations

import argparse
import os
import pty
import re
import select
import signal
import subprocess
import sys
import time

SKIP_RC = 2

FATAL_RE = re.compile(
    r"\bpanic\b|SIGSEGV|Segmentation fault|assertion failed|kernel panic|PM: coredump signal",
    re.IGNORECASE,
)

INIT_MARKER = "virtio-net-mmio: initialized"


def log(msg: str) -> None:
    print(msg, flush=True)


def log_tail(buf: str, label: str, limit: int = 4000) -> None:
    tail = buf[-limit:] if buf else ""
    log(f"{label} output tail:\n{tail}")


class ProcIO:
    def __init__(self, proc: subprocess.Popen, read_fd: int, write_fd: int):
        self.proc = proc
        self.read_fd = read_fd
        self.write_fd = write_fd


def spawn(cmd: list[str]) -> ProcIO:
    try:
        master_fd, slave_fd = pty.openpty()
    except OSError:
        proc = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            close_fds=True,
            bufsize=0,
        )
        if proc.stdin is None or proc.stdout is None:
            raise RuntimeError("failed to open pipes for QEMU")
        return ProcIO(proc, proc.stdout.fileno(), proc.stdin.fileno())

    proc = subprocess.Popen(
        cmd,
        stdin=slave_fd,
        stdout=slave_fd,
        stderr=slave_fd,
        close_fds=True,
    )
    os.close(slave_fd)
    return ProcIO(proc, master_fd, master_fd)


def send(io: ProcIO, data: str) -> None:
    os.write(io.write_fd, data.encode())


def read_until(
    io: ProcIO,
    patterns: list[re.Pattern[str]],
    timeout: float,
) -> tuple[str, re.Pattern[str] | None]:
    buf = ""
    deadline = time.time() + timeout

    while time.time() < deadline:
        rlist, _, _ = select.select([io.read_fd], [], [], 0.2)
        if io.read_fd in rlist:
            data = os.read(io.read_fd, 4096)
            if not data:
                break
            chunk = data.decode(errors="ignore")
            buf += chunk
            for pat in patterns:
                if pat.search(buf):
                    return buf, pat
    return buf, None


def run_command(
    io: ProcIO,
    cmd_name: str,
    cmd: str,
    timeout: int,
) -> bool:
    rc_pat = re.compile(rf"__RUNTIME_RC__{re.escape(cmd_name)}:(\d+)")

    send(io, cmd + "\n")
    send(io, f"echo __RUNTIME_RC__{cmd_name}:$?\n")

    buf, _ = read_until(io, [rc_pat, FATAL_RE], timeout)
    if FATAL_RE.search(buf):
        log_tail(buf, f"Fatal signature while running {cmd_name}")
        log(f"FAIL: {cmd_name} hit fatal signature")
        return False

    m = rc_pat.search(buf)
    if m is None:
        log_tail(buf, f"Missing return marker for {cmd_name}")
        log(f"FAIL: {cmd_name} missing return marker")
        return False

    rc = int(m.group(1))
    if rc != 0:
        log_tail(buf, f"Command {cmd_name} failed (rc={rc})")
        log(f"FAIL: {cmd_name} rc={rc}")
        return False

    log(f"[PASS] runtime cmd={cmd_name}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--qemu-script", required=True)
    parser.add_argument("--kernel", required=True)
    parser.add_argument("--destdir", required=True)
    parser.add_argument("--disk")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--cmd-timeout", type=int, default=45)
    args = parser.parse_args()

    if not os.path.exists(args.qemu_script):
        log("SKIP: qemu script not found")
        return SKIP_RC
    if not os.path.exists(args.kernel):
        log("SKIP: kernel not found")
        return SKIP_RC
    if not os.path.isdir(args.destdir):
        log("SKIP: destdir not found")
        return SKIP_RC

    os.environ["NET_HOSTFWD"] = "none"

    qemu_cmd = [
        args.qemu_script,
        "-s",
        "-k",
        args.kernel,
        "-B",
        args.destdir,
        "-n",
    ]
    if args.disk:
        qemu_cmd.extend(["-i", args.disk])

    log("Starting QEMU net smoke...")
    io = spawn(qemu_cmd)
    proc = io.proc

    try:
        login_pat = re.compile(r"login:", re.IGNORECASE)
        passwd_pat = re.compile(r"password:", re.IGNORECASE)
        prompt_pat = re.compile(r"\n.*[#\\$] ")

        boot = ""
        buf, _ = read_until(io, [login_pat, prompt_pat, FATAL_RE], args.timeout)
        boot += buf
        if FATAL_RE.search(buf):
            log_tail(buf, "Fatal signature before prompt")
            log("FAIL: fatal signature before prompt")
            return 1

        if login_pat.search(buf):
            send(io, "root\n")
            buf, pat = read_until(io, [passwd_pat, prompt_pat, FATAL_RE], args.timeout)
            boot += buf
            if FATAL_RE.search(buf):
                log_tail(buf, "Fatal signature during login")
                log("FAIL: fatal signature during login")
                return 1
            if pat == passwd_pat:
                send(io, "\n")
                buf, _ = read_until(io, [prompt_pat, FATAL_RE], args.timeout)
                boot += buf
                if FATAL_RE.search(buf):
                    log_tail(buf, "Fatal signature after password")
                    log("FAIL: fatal signature after password")
                    return 1

        if not prompt_pat.search(buf):
            log_tail(boot, "Shell prompt not detected")
            log("FAIL: shell prompt not detected")
            return 1

        if INIT_MARKER not in boot:
            log_tail(boot, "Missing virtio-net-mmio init marker")
            log(f"FAIL: {INIT_MARKER} not found")
            return 1
        log(f"[PASS] {INIT_MARKER}")

        commands: list[tuple[str, str]] = [
            (
                "ifconfig_vio",
                "PATH=/sbin:/bin:/usr/bin; /sbin/ifconfig vio0",
            ),
            (
                "ping6_lo",
                "PATH=/sbin:/bin:/usr/bin; /sbin/ping6 -c 1 ::1",
            ),
            (
                "ping_gw",
                "PATH=/sbin:/bin:/usr/bin; /sbin/ping -c 2 10.0.2.2",
            ),
        ]

        for name, command in commands:
            if not run_command(io, name, command, args.cmd_timeout):
                return 1

        send(io, "echo __RUNTIME_OK__\n")
        buf, _ = read_until(io, [re.compile(r"__RUNTIME_OK__"), FATAL_RE], args.cmd_timeout)
        if FATAL_RE.search(buf):
            log_tail(buf, "Fatal signature at probe tail")
            log("FAIL: fatal signature at probe tail")
            return 1
        if "__RUNTIME_OK__" not in buf:
            log_tail(buf, "Probe completion marker missing")
            log("FAIL: probe completion marker missing")
            return 1

        log("PASS: qemu net smoke")
        return 0
    finally:
        try:
            send(io, "\x01x")
        except OSError:
            pass
        try:
            proc.send_signal(signal.SIGTERM)
            proc.wait(timeout=5)
        except Exception:
            proc.kill()


if __name__ == "__main__":
    sys.exit(main())
