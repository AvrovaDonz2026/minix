#!/usr/bin/env python3
"""
QEMU runtime probe for MINIX/i386 (multiboot + initrd).

Reuses the riscv64 probe logic with i386-specific defaults.
"""

from __future__ import annotations

import importlib.util
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RV_PROBE = os.path.join(SCRIPT_DIR, "..", "riscv64", "qemu_runtime_probe.py")

spec = importlib.util.spec_from_file_location("qemu_runtime_probe_rv64", RV_PROBE)
if spec is None or spec.loader is None:
    raise SystemExit(f"missing probe helper: {RV_PROBE}")
mod = importlib.util.module_from_spec(spec)
sys.modules["qemu_runtime_probe_rv64"] = mod
spec.loader.exec_module(mod)

if __name__ == "__main__":
    sys.exit(mod.main())
