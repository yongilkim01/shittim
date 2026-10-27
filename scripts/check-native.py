#!/usr/bin/env python3
"""Compile pinned native sources against actual installed headers, without loading a plugin."""
import importlib.util
import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    spec=importlib.util.spec_from_file_location('shittim_native_ci',ROOT/'scripts/titlebar-tool.py')
    tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
    flags=subprocess.run(['pkg-config','--cflags','--keep-system-cflags','hyprland'],check=True,capture_output=True,text=True,timeout=10).stdout
    versions=[Path(flag[2:])/'hyprland/src/version.h' for flag in shlex.split(flags) if flag.startswith('-I')]
    commit=None
    for path in versions:
        if path.is_file():
            match=re.search(r'#define GIT_COMMIT_HASH\s+"([0-9a-f]{40})"',path.read_text())
            if match:commit=match[1];break
    if not commit:raise SystemExit('Installed Hyprland version header could not be identified')
    revision=tool.revision({'commit':commit})
    with tempfile.TemporaryDirectory(prefix='shittim-native-ci-') as temporary:
        base=Path(temporary)
        for name,relative in [('HOME','.'),('XDG_CONFIG_HOME','config'),('XDG_DATA_HOME','data'),('XDG_STATE_HOME','state')]:os.environ[name]=str(base/relative)
        config=tool.files.Config(ROOT,base)
        # This private manifest is deliberately not a deployable ABI identity.
        try:tool.plugin.build(config,{'commit':commit,'abiHash':'compile-only-not-for-deployment'},revision)
        except Exception:
            log=config.state/'titlebars-build.log'
            if log.is_file():print(log.read_text(errors='replace')[-16000:])
            raise
        print('Pinned native source compiled against installed Hyprland headers; not loaded.')


if __name__=='__main__':main()
