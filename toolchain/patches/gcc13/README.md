# GCC 13 Patch Stack (Patch-Only Policy)

This directory stores local MINIX adaptations for GCC 13 as patch files.

Policy:
- Do not commit direct edits under `external/gpl3/gcc/dist`.
- Keep GCC 13 adaptations as numbered `*.patch` files in this directory.
- Apply patches in lexical order during CI or local prep scripts.

Recommended naming:
- `0001-...patch`
- `0002-...patch`

Current status:
- Bootstrap scaffold only.
- No GCC 13 MINIX port patchset has been committed yet.
