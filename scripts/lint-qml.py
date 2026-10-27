#!/usr/bin/env python3
"""Gate syntax/import/type construction; retain all other qmllint diagnostics in the report."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]


def main():
    executable=shutil.which('qmllint') or '/usr/lib/qt6/bin/qmllint'
    if not Path(executable).is_file():raise SystemExit('qt6-declarative qmllint is required')
    paths=sorted((ROOT/'shell').rglob('*.qml'))
    with tempfile.TemporaryDirectory(prefix='shittim-lint-') as temporary:
        report=Path(temporary)/'report.json'
        result=subprocess.run([executable,'--ignore-settings','-E','--json',str(report),'-I','/usr/lib/qt6/qml',*[str(p) for p in paths]],capture_output=True,text=True,timeout=120)
        if not report.is_file():raise SystemExit(result.stderr or 'qmllint did not write a report')
        data=json.loads(report.read_text())
        blocking={'import','syntax','required','alias-cycle','unresolved-alias','inheritance-cycle','unresolved-type'}
        failed=[];warnings=0
        for item in data.get('files',[]):
            for issue in item.get('warnings',[]):
                warnings+=1
                # Quickshell 0.3.2 exposes this pointer as an unqualified C++ name
                # although its exported type is qs::bluetooth::BluetoothAdapter.
                # Keep the warning in the report; the real-import session test covers it.
                upstream_adapter_metadata=(Path(item['filename']).name=='BluetoothState.qml' and issue.get('id')=='unresolved-type'
                    and issue['message'].startswith('Type "BluetoothAdapter" of property "defaultAdapter" not found.'))
                if issue.get('type')=='error' or issue.get('id') in blocking and not upstream_adapter_metadata:
                    failed.append(f'{item["filename"]}:{issue.get("line",0)} [{issue.get("id")}] {issue["message"]}')
        print('\n'.join(failed) if failed else f'QML syntax/import gate passed ({len(paths)} files, {warnings} diagnostics).')
        # CI log contains the complete machine-readable report, including nonblocking style/dynamic-var diagnostics.
        print(json.dumps(data))
        return 1 if failed else 0


if __name__=='__main__':sys.exit(main())
