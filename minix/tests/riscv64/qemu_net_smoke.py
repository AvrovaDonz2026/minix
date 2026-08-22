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
import struct
import subprocess
import sys
import tempfile
import time

SKIP_RC = 2

FATAL_RE = re.compile(
    r"\bpanic\b|SIGSEGV|Segmentation fault|assertion failed|kernel panic|PM: coredump signal",
    re.IGNORECASE,
)

INIT_MARKER = "virtio-net-mmio: initialized"
MAC_MARKER = "virtio-net-mmio: mac 52:54:00:12:34:56"
HDR_MARKER = "virtio-net-mmio: hdr 12"
MRG_MARKER = "mrg on"
EVENT_IDX_MARKER = "event_idx on"
RX_RING_MARKER = "rx 256"

SLIRP_IPS = frozenset({"10.0.2.2", "10.0.2.15"})


def log(msg: str) -> None:
    print(msg, flush=True)


def log_tail(buf: str, label: str, limit: int = 4000) -> None:
    tail = buf[-limit:] if buf else ""
    log(f"{label} output tail:\n{tail}")


def setup_net_pcap() -> str:
    existing = os.environ.get("NET_PCAP")
    if existing:
        return existing
    fd, path = tempfile.mkstemp(suffix=".pcap")
    os.close(fd)
    os.environ["NET_PCAP"] = path
    return path


def ipv4_addr(pkt: bytes, offset: int) -> str:
    return ".".join(str(pkt[offset + i]) for i in range(4))


def parse_pcap(path: str) -> tuple[int, int, int, int, int]:
    arp_req = 0
    arp_rep = 0
    echo_req = 0
    echo_rep = 0

    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return 0, 0, 0, 0, 0

    size = len(data)
    if size < 24:
        return 0, 0, 0, 0, size

    magic = struct.unpack_from("<I", data, 0)[0]
    if magic == 0xa1b2c3d4:
        endian = ">"
        rec_endian = ">"
    elif magic == 0xd4c3b2a1:
        endian = "<"
        rec_endian = "<"
    else:
        return 0, 0, 0, 0, size

    offset = 24
    while offset + 16 <= len(data):
        _, _, incl_len, _ = struct.unpack_from(rec_endian + "IIII", data, offset)
        offset += 16
        if incl_len > len(data) - offset:
            pkt = data[offset:]
        else:
            pkt = data[offset:offset + incl_len]
        offset += incl_len

        caplen = len(pkt)
        if caplen < 14:
            continue

        ethertype = struct.unpack_from(">H", pkt, 12)[0]
        if ethertype == 0x0806:
            if caplen >= 22:
                opcode = struct.unpack_from(">H", pkt, 20)[0]
                if opcode == 1:
                    arp_req += 1
                elif opcode == 2:
                    arp_rep += 1
        elif ethertype == 0x0800:
            ip_off = 14
            if caplen < ip_off + 20:
                continue
            ihl = (pkt[ip_off] & 0x0f) * 4
            if caplen < ip_off + ihl + 1:
                continue
            if pkt[ip_off + 9] != 1:
                continue
            src = ipv4_addr(pkt, ip_off + 12)
            dst = ipv4_addr(pkt, ip_off + 16)
            icmp_off = ip_off + ihl
            icmp_type = pkt[icmp_off]
            if icmp_type == 8 and (src in SLIRP_IPS or dst in SLIRP_IPS):
                echo_req += 1
            elif icmp_type == 0 and (src in SLIRP_IPS or dst in SLIRP_IPS):
                echo_rep += 1

    return arp_req, arp_rep, echo_req, echo_rep, size


def analyze_pcap(pcap_path: str, ping_gw_failed: bool) -> None:
    if not pcap_path or not os.path.exists(pcap_path):
        return

    arp_req, arp_rep, echo_req, echo_rep, nbytes = parse_pcap(pcap_path)
    if nbytes <= 0:
        return

    log(
        f"pcap: arp_req={arp_req} arp_rep={arp_rep} "
        f"echo_req={echo_req} echo_rep={echo_rep} bytes={nbytes}"
    )

    if ping_gw_failed:
        if echo_req == 0:
            log("ping_gw failed: no ICMP echo request left the guest (TX path)")
        elif echo_rep == 0:
            log(
                "ping_gw failed: SLIRP saw echo request but no reply "
                "(RX/EVENT_IDX path)"
            )
        else:
            log(
                "ping_gw failed: echo request/reply frames were on the wire "
                "but guest ping still failed"
            )


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
        if io.read_fd not in rlist:
            if io.proc.poll() is not None:
                break
            continue
        try:
            data = os.read(io.read_fd, 4096)
        except BlockingIOError:
            continue
        except OSError:
            # Dead PTY after QEMU exits (EIO on Linux).
            break
        if not data:
            break
        buf += data.decode(errors="ignore")
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
    pcap_path = setup_net_pcap()
    ping_gw_failed = False

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
    ping_gw_failed = False

    try:
        login_pat = re.compile(r"login:", re.IGNORECASE)
        passwd_pat = re.compile(r"password:", re.IGNORECASE)
        # OpenSBI's banner contains `\ ` which a loose `[#$] ` prompt matches.
        prompt_pat = re.compile(r"(?:^|\r?\n)# ")

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

        if MAC_MARKER not in boot:
            log_tail(boot, "Missing virtio-net-mmio MAC marker")
            log(f"FAIL: {MAC_MARKER} not found")
            return 1
        log(f"[PASS] {MAC_MARKER}")

        if HDR_MARKER not in boot:
            log_tail(boot, "Missing modern virtio-net header marker")
            log(f"FAIL: {HDR_MARKER} not found")
            return 1
        log(f"[PASS] {HDR_MARKER}")

        if MRG_MARKER not in boot:
            log_tail(boot, "Missing mergeable RX marker")
            log(f"FAIL: {MRG_MARKER} not found")
            return 1
        log(f"[PASS] {MRG_MARKER}")

        if EVENT_IDX_MARKER not in boot:
            log_tail(boot, "Missing EVENT_IDX marker")
            log(f"FAIL: {EVENT_IDX_MARKER} not found")
            return 1
        log(f"[PASS] {EVENT_IDX_MARKER}")

        if RX_RING_MARKER not in boot:
            log_tail(boot, "Missing 256-slot RX ring marker")
            log(f"FAIL: {RX_RING_MARKER} not found")
            return 1
        log(f"[PASS] {RX_RING_MARKER}")

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
                if name == "ping_gw":
                    ping_gw_failed = True
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
        exit_rc = 0
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
        analyze_pcap(pcap_path, ping_gw_failed)


if __name__ == "__main__":
    sys.exit(main())
