#!/usr/bin/env python3
"""Guided lock and power test on the real session (docs/power.md checklist in one run).

The person types passwords, closes the lid and unplugs the adapter; this script prompts for each step and
checks the result itself (hyprctl lock state, DPMS, windows, inhibitors, a suspend through the boot clock).
Settings are shortened only for the test and always restored; automatic suspend stays off throughout.
Never reads, asks for or logs a password.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
LABELS = {'PASS': '통과', 'FAIL': '실패', 'SKIP': '건너뜀'}


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


policy = module('shittim_power_policy', 'power-policy.py')


def run(args, timeout=10):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return result.returncode, result.stdout
    except (OSError, subprocess.TimeoutExpired):
        return 1, ''


def hyprctl_json(*args):
    code, output = run(['hyprctl', '-j', *args])
    try:
        return json.loads(output) if code == 0 else None
    except ValueError:
        return None


def locked():
    data = hyprctl_json('locked')
    return bool(data and data.get('locked'))


def screens_on():
    monitors = hyprctl_json('monitors') or []
    return [bool(item.get('dpmsStatus')) for item in monitors]


def windows():
    return sorted(str(item.get('address')) for item in hyprctl_json('clients') or [])


def hyprlock_count():
    code, output = run(['pgrep', '-u', str(os.getuid()), '-x', 'hyprlock'])
    return len(output.split()) if code == 0 else 0


def idle_inhibited_by_shittim():
    code, output = run(['systemd-inhibit', '--list', '--no-pager', '--no-legend'])
    return any('Shittim' in line and 'idle' in line for line in output.splitlines())


def slept_seconds():
    """Time spent suspended since boot: the boot clock keeps counting during suspend, the monotonic clock does not."""
    return time.clock_gettime(time.CLOCK_BOOTTIME) - time.monotonic()


def wait_until(check, timeout, interval=0.5):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if check():
            return True
        time.sleep(interval)
    return check()


class Settings:
    """Backs up ~/.config/shittim/power.json and puts it back exactly, even when the test is interrupted."""
    def __init__(self, root=ROOT):
        self.root = root
        self.personal = policy.paths(root)[1]
        self.original = self.personal.read_bytes() if self.personal.exists() else None
        self.changed = False

    def set(self, source, **values):
        for key, value in values.items():
            policy.update(source, key, str(value), self.root)
        self.changed = True

    def restore(self):
        if not self.changed:
            return
        if self.original is None:
            self.personal.unlink(missing_ok=True)
        else:
            temporary = self.personal.with_name('.power.json.test-restore')
            temporary.write_bytes(self.original)
            os.replace(temporary, self.personal)
        self.changed = False


class Tester:
    def __init__(self, ask=input, out=print):
        self.ask, self.out = ask, out
        self.results = []
        self.settings = Settings()
        self.runtime = Path(os.environ.get('XDG_RUNTIME_DIR') or '/run/user/' + str(os.getuid())) / 'shittim'
        self.keep_awake_on = False

    # --- helpers -------------------------------------------------------------------------------
    def status(self):
        try:
            data = json.loads((self.runtime / 'power-status.json').read_text(encoding='utf-8'))
            return data if time.time() - data['time'] < 10 else None
        except (OSError, ValueError, KeyError):
            return None

    def record(self, name, outcome, detail=''):
        self.results.append((name, outcome, detail))
        self.out(f'  → [{LABELS[outcome]}] {name}' + (f' · {detail}' if detail else ''))

    def confirm(self, question):
        while True:
            answer = self.ask(f'  {question} [y/n] ').strip().lower()
            if answer in ('y', 'n'):
                return answer == 'y'

    def ready(self, title, lines):
        self.out('\n■ ' + title)
        for line in lines:
            self.out('  · ' + line)
        answer = self.ask('  준비되면 Enter, 이 항목을 건너뛰려면 s 후 Enter: ').strip().lower()
        if answer == 's':
            self.record(title, 'SKIP', '사용자 선택')
            return False
        return True

    def apply(self, source, **values):
        """Changes settings and waits until the idle service reports them applied."""
        self.settings.set(source, **values)
        wanted = policy.read_settings(ROOT)[0][source]
        return wait_until(lambda: (self.status() or {}).get('applied') == wanted and self.status().get('idle') == 'running', 10)

    def ipc(self, function):
        return run(['quickshell', 'ipc', '--path', str(ROOT / 'shell/shell.qml'), 'call', 'power', function])

    def wait_unlock(self, timeout=300):
        return wait_until(lambda: not locked(), timeout, 1)

    # --- steps -----------------------------------------------------------------------------------
    def check_service(self):
        status = self.status()
        if not status or status.get('idle') != 'running':
            self.record('자동 잠금 서비스', 'FAIL', 'systemctl --user start shittim-idle.service 후 다시 실행하세요')
            return None
        self.record('자동 잠금 서비스', 'PASS', '전원: ' + ('배터리' if status['source'] == 'battery' else '연결'))
        return status

    def manual_lock(self):
        name = '수동 잠금 · 중복 잠금 · 창 유지'
        monitors = len(screens_on())
        if not self.ready(name, ['스크립트가 화면을 잠급니다.',
                                 '잠금 화면에서 먼저 틀린 비밀번호를 한 번 입력해 오류 문구를 확인하세요.',
                                 '그다음 맞는 비밀번호 + Enter 로 해제하세요.'] +
                          (['모니터가 여러 대입니다. 모든 모니터가 잠금 화면인지도 봐 두세요.'] if monitors > 1 else [])):
            return
        before = windows()
        subprocess.run(['/usr/bin/bash', str(ROOT / 'scripts/power-action.sh'), 'lock'], capture_output=True, timeout=15)
        if not wait_until(locked, 10):
            self.record(name, 'FAIL', '잠기지 않음 (hyprctl locked = false)')
            return
        # A second request while locked must not start another hyprlock.
        subprocess.run(['/usr/bin/bash', str(ROOT / 'scripts/lock-screen.sh')], capture_output=True, timeout=10)
        time.sleep(2)
        duplicate_ok = hyprlock_count() == 1 and locked()
        if not self.wait_unlock():
            self.record(name, 'FAIL', '5분 안에 해제되지 않음')
            return
        failures = []
        if not duplicate_ok:
            failures.append('중복 잠금 시 hyprlock 이 1개가 아님')
        if windows() != before:
            failures.append('해제 후 창 목록이 달라짐')
        if not self.confirm('틀린 비밀번호에 «비밀번호가 올바르지 않습니다» 가 보였고, 맞는 비밀번호로 풀렸나요?'):
            failures.append('비밀번호 처리 확인 안 됨')
        if monitors > 1 and not self.confirm('모든 모니터가 잠금 화면이었나요?'):
            failures.append('일부 모니터가 잠기지 않음')
        if not self.confirm('잠금 화면 배치가 목업(로고·시계·날짜·카드·하단 상태)과 맞았나요?'):
            failures.append('잠금 화면 배치 다름')
        self.record(name, 'FAIL' if failures else 'PASS', ', '.join(failures))

    def control_center_lock(self):
        name = 'Control Center 잠금'
        if not self.ready(name, ['Enter 후 60초 안에 TopBar → Control Center → Power → «잠금» 을 누르세요.', '잠기면 비밀번호로 해제하세요.']):
            return
        if not wait_until(locked, 60):
            self.record(name, 'FAIL', '60초 안에 잠기지 않음')
            return
        self.record(name, 'PASS' if self.wait_unlock() else 'FAIL')

    def auto_lock_and_screen_off(self, source):
        name = '자동 잠금 1분 · 화면 끄기 2분'
        if not self.ready(name, ['설정을 잠시 자동 잠금 1분 · 화면 끄기 2분 · 자동 절전 끔으로 바꿉니다(끝나면 되돌림).',
                                 'Enter 후 키보드·마우스를 만지지 마세요. 약 1분 뒤 잠기고 2분 뒤 화면이 꺼집니다.',
                                 '화면이 꺼지면 아무 키나 눌러 켜고 비밀번호로 해제하세요.']):
            return
        if not self.apply(source, lock=1, screenOff=2, suspend=0):
            self.record(name, 'FAIL', '설정이 적용되지 않음 (power-status.json 확인)')
            return
        failures = []
        if not wait_until(locked, 90, 1):
            failures.append('90초 안에 자동 잠금 안 됨')
        elif not wait_until(lambda: not all(screens_on()), 90, 1):
            failures.append('잠금 후 화면이 꺼지지 않음')
        if not wait_until(lambda: all(screens_on()) and not locked(), 300, 1):
            failures.append('화면 복귀 또는 해제 확인 안 됨')
        self.record(name, 'FAIL' if failures else 'PASS', ', '.join(failures))

    def keep_awake(self, source):
        name = '절전 방지'
        if not self.ready(name, ['자동 잠금 1분 상태에서 절전 방지를 켜고 80초 동안 잠기지 않는지 봅니다.',
                                 '그다음 절전 방지를 끄고 다시 1분 안에 잠기는지 봅니다. 잠기면 비밀번호로 해제하세요.',
                                 'Enter 후에는 키보드·마우스를 만지지 마세요.']):
            return
        if not self.apply(source, lock=1, screenOff=0, suspend=0):
            self.record(name, 'FAIL', '설정이 적용되지 않음')
            return
        code, _ = self.ipc('toggleKeepAwake')
        self.keep_awake_on = code == 0
        failures = []
        if not wait_until(idle_inhibited_by_shittim, 5):
            failures.append('Shittim idle inhibitor 가 생기지 않음 (Shittim 실행 확인)')
        elif wait_until(locked, 80, 1):
            failures.append('절전 방지 중인데 잠김')
            self.wait_unlock()
        self.ipc('toggleKeepAwake')
        self.keep_awake_on = False
        if wait_until(idle_inhibited_by_shittim, 3):
            failures.append('절전 방지를 꺼도 inhibitor 가 남음')
        if not wait_until(locked, 90, 1):
            failures.append('절전 방지를 끈 뒤 자동 잠금 안 됨')
        elif not self.wait_unlock():
            failures.append('해제 확인 안 됨')
        if not failures and not self.confirm('절전 방지가 켜져 있는 동안 TopBar 에 커피 아이콘이 보였나요?'):
            failures.append('TopBar 아이콘 확인 안 됨')
        self.record(name, 'FAIL' if failures else 'PASS', ', '.join(failures))

    def power_source(self, status):
        name = '전원 연결 / 분리 감지'
        if not status.get('hasBattery'):
            self.record(name, 'SKIP', '배터리 없음')
            return
        first = status['source']
        action, back = ('어댑터를 뽑으세요', '어댑터를 다시 꽂으세요') if first == 'ac' else ('어댑터를 꽂으세요', '어댑터를 다시 뽑으세요')
        if not self.ready(name, [f'Enter 후 60초 안에 {action}.']):
            return
        changed = wait_until(lambda: (self.status() or {}).get('source') not in (None, first), 60, 1)
        self.out(f'  · 이제 60초 안에 {back}.')
        restored = wait_until(lambda: (self.status() or {}).get('source') == first, 60, 1)
        self.record(name, 'PASS' if changed and restored else 'FAIL', '' if changed and restored else '전원 상태 변화가 감지되지 않음')

    def suspend(self):
        name = '수동 절전 · 복귀 후 잠금'
        if not self.ready(name, ['실제로 절전합니다. 작업을 저장했는지 확인하세요.',
                                 'Enter 후 60초 안에 Control Center → Power → «절전» 을 두 번 누르세요.',
                                 '절전되면 몇 초 뒤 전원 버튼이나 키를 눌러 깨우고, 잠금 화면에서 비밀번호로 해제하세요.']):
            return
        start = slept_seconds()
        if not wait_until(lambda: slept_seconds() - start > 3, 120, 1):
            self.record(name, 'FAIL', '절전하지 않음 (Control Center 오류 문구·알림 확인)')
            return
        # Right after resume the session must already be locked.
        locked_after = locked()
        unlocked = self.wait_unlock()
        failures = [] if locked_after else ['복귀 직후 잠겨 있지 않음 — 보안 문제']
        if not unlocked:
            failures.append('해제 확인 안 됨')
        self.record(name, 'FAIL' if failures else 'PASS', ', '.join(failures))

    def lid(self, status, source):
        name = '덮개 닫기 → 절전'
        if not (status.get('lid') or {}).get('present'):
            self.record(name, 'SKIP', '덮개 없음')
            return
        if not self.ready(name, ['덮개 설정을 잠시 «절전» 으로 바꿉니다(끝나면 되돌림). 실제로 절전합니다.',
                                 'Enter 후 덮개를 닫고 5초 뒤 여세요. 잠금 화면에서 비밀번호로 해제하세요.',
                                 '외부 모니터가 연결돼 있으면 뽑고 하세요(연결 중에는 일부러 아무것도 하지 않음).']):
            return
        if not self.apply(source, lid='suspend', suspend=0):
            self.record(name, 'FAIL', '설정이 적용되지 않음')
            return
        lid = (self.status() or {}).get('lid') or {}
        if not lid.get('inhibited'):
            self.record(name, 'FAIL', 'logind 덮개 처리를 가져오지 못함 (' + (lid.get('error') or '권한') + ') — 시스템 설정으로 동작')
            return
        start = slept_seconds()
        if not wait_until(lambda: slept_seconds() - start > 3, 120, 1):
            self.record(name, 'FAIL', '덮개를 닫아도 절전하지 않음')
            return
        locked_after = locked()
        unlocked = self.wait_unlock()
        failures = [] if locked_after else ['복귀 직후 잠겨 있지 않음 — 보안 문제']
        if not unlocked:
            failures.append('해제 확인 안 됨')
        self.record(name, 'FAIL' if failures else 'PASS', ', '.join(failures))

    # --- run -------------------------------------------------------------------------------------
    def summary(self):
        counts = {outcome: sum(1 for _, value, _ in self.results if value == outcome) for outcome in ('PASS', 'FAIL', 'SKIP')}
        lines = ['', '=== 전원·잠금 실기 검사 결과 ===']
        for name, outcome, detail in self.results:
            lines.append(f'[{LABELS[outcome]}] {name}' + (f' · {detail}' if detail else ''))
        lines.append(f'통과 {counts["PASS"]} · 실패 {counts["FAIL"]} · 건너뜀 {counts["SKIP"]}')
        return '\n'.join(lines)

    def run(self, with_suspend):
        status = self.check_service()
        if not status:
            return 1
        source = status['source']
        try:
            self.manual_lock()
            self.control_center_lock()
            self.auto_lock_and_screen_off(source)
            self.settings.restore()
            self.keep_awake(source)
            self.settings.restore()
            self.power_source(self.status() or status)
            if with_suspend:
                self.suspend()
                self.lid(self.status() or status, (self.status() or status)['source'])
            else:
                self.record('수동 절전 · 복귀 후 잠금', 'SKIP', '--with-suspend 없이 실행')
                self.record('덮개 닫기 → 절전', 'SKIP', '--with-suspend 없이 실행')
        finally:
            if self.keep_awake_on:
                self.ipc('toggleKeepAwake')
            self.settings.restore()
        text = self.summary()
        self.out(text)
        log = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'shittim' / time.strftime('power-test-%Y%m%d-%H%M%S.txt')
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text(text + '\n', encoding='utf-8')
        self.out('결과 저장: ' + str(log))
        return 1 if any(outcome == 'FAIL' for _, outcome, _ in self.results) else 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if any(arg not in ('--with-suspend',) for arg in argv):
        print('사용법: test-power.sh [--with-suspend]', file=sys.stderr)
        return 2
    if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE') or not shutil.which('hyprctl'):
        print('[Shittim:오류] Hyprland 세션의 터미널에서 실행하세요.', file=sys.stderr)
        return 1
    print('Shittim 전원·잠금 실기 검사 (docs/power.md 수동 검사 순서)')
    print('· 이 검사는 화면을 잠그고 끕니다' + (' · 실제로 절전합니다' if argv else '') + '. 열린 작업을 저장하세요.')
    print('· 설정은 검사 중에만 바꾸고 끝나면(중간에 Ctrl+C 해도) 되돌립니다. 자동 절전은 검사 내내 꺼 둡니다.')
    print('· 비밀번호는 잠금 화면에만 입력합니다. 이 스크립트는 비밀번호를 묻거나 기록하지 않습니다.')
    if input('시작하려면 yes 를 입력하세요: ').strip() != 'yes':
        print('취소했습니다.')
        return 1
    try:
        return Tester().run('--with-suspend' in argv)
    except KeyboardInterrupt:
        print('\n중단했습니다. 설정은 되돌렸습니다.')
        return 130


if __name__ == '__main__':
    raise SystemExit(main())
