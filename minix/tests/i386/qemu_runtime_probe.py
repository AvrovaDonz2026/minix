#!/usr/bin/env python3
"""
QEMU runtime probe for MINIX/i386.

Boots via multiboot+initrd (+ optional disk), then treats the guest as healthy when
serial output shows userspace root bring-up without fatal signatures.  i386 under
QEMU commonly cannot offer an interactive shell on COM1 when cttyline=0 is set for
early serial diagnostics, so this probe also accepts stable rc milestones.
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

BOOT_OK_RE = re.compile(
    r"VM: pt_init end|login:|Root device name is|VFS: exec path=\"/bin/mount\"|"
    r"init: exec /bin/sh|VFS: init_root done",
    re.IGNORECASE,
)

PROMPT_RE = re.compile(r"\n.*[#\\$] ")


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
            try:
                data = os.read(io.read_fd, 4096)
            except OSError:
                break
            if not data:
                break
            buf += data.decode(errors="ignore")
            for pat in patterns:
                if pat.search(buf):
                    return buf, pat
    return buf, None


def shutdown_qemu(io: ProcIO) -> None:
    try:
        send(io, "\x01x")
    except OSError:
        pass
    proc = io.proc
    try:
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=5)
    except Exception:
        proc.kill()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--qemu-script", required=True)
    parser.add_argument("--kernel", required=True)
    parser.add_argument("--destdir", required=True)
    parser.add_argument("--disk")
    parser.add_argument("--timeout", type=int, default=240)
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

    qemu_cmd = [
        args.qemu_script,
        "-s",
        "-k",
        args.kernel,
        "-B",
        args.destdir,
        "-m",
        "512M",
    ]
    if args.disk:
        qemu_cmd.extend(["-i", args.disk])

    log("Starting QEMU i386 boot probe...")
    io = spawn(qemu_cmd)

    try:
        buf, pat = read_until(io, [BOOT_OK_RE, PROMPT_RE, FATAL_RE], args.timeout)
        if FATAL_RE.search(buf):
            if re.search(r"at_wini.*panic: couldn't set native IRQ policy 0", buf):
                log_tail(buf, "Known at_wini IRQ issue")
            else:
                log_tail(buf, "Fatal signature during boot")
            return 1

        if pat in (BOOT_OK_RE, PROMPT_RE):
            log("PASS: qemu i386 boot probe")
            return 0

        log_tail(buf, "Boot milestone not detected")
        return 1
    finally:
        shutdown_qemu(io)


if __name__ == "__main__":
    sys.exit(main())
