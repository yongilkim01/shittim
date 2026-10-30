# 네트워크 설정

대시보드 «네트워크» 메뉴. Wi-Fi·유선·저장된 연결을 탭으로 나누고, 선택한 연결의 IP·DNS·MAC·자동 연결·프록시, 실시간 트래픽, 연결 상태와 요청형 진단을 보여 준다. 모든 값은 NetworkManager와 `/proc/net/dev`가 실제로 알려 주는 것만 쓴다.

## 구조

| 층 | 파일 | 책임 |
| --- | --- | --- |
| 화면 | `shell/components/control/NetworkSettingsPage.qml` | 탭·목록·상세·편집기·비밀번호/숨겨진 네트워크/삭제 대화상자. 아래 두 서비스의 계약만 호출한다 |
| 확인 카드 | `control/NetworkConfirmCard.qml`, `components/NetworkConfirm.qml` | «변경된 네트워크 설정을 유지하시겠습니까?» 화면 안 / 화면이 닫혔을 때 모든 모니터 위 |
| 상태 | `shell/services/NetworkState.qml` | Wi-Fi 켜기·끄기, 검색, 주변 네트워크, 연결·비밀번호, 인터넷 연결 상태(`Quickshell.Networking`). TopBar·제어 센터와 같은 객체 |
| 상태 | `shell/services/NetworkSettingsState.qml` | 어댑터 프로세스 수명, 요청 대장, 장치 상세·저장된 연결·복원 대기·진단 결과 |
| 계산 | `shell/core/NetworkData.js` | IPv4/IPv6 검증, 문구(상태·보안·대역·진단), 편집기 양식 ↔ 요청 (단위 시험) |
| 어댑터 | `scripts/network-service.py` | NetworkManager D-Bus(`python-dbus-next`): 읽기, 프로필 변경, 체크포인트, 진단 |
| 트래픽 | `scripts/dashboard-service.py` → `DashboardModel.history` | 시스템 화면과 같은 수집기 1개. 네트워크 화면이 보일 때도 실행 |

TopBar의 Wi-Fi·유선 아이콘, 제어 센터 Wi-Fi 페이지, 대시보드 네트워크 화면은 모두 같은 `NetworkState`를 본다. 어디서 Wi-Fi를 끄든 다른 화면도 NetworkManager 신호로 바로 바뀐다. 어댑터는 NetworkManager 신호가 올 때만 다시 읽고(0.4초 묶음), 주기적으로 묻지 않는다. 어댑터는 네트워크 화면이 열려 있거나, 요청이 처리 중이거나, 복원 대기가 있을 때만 실행된다.

## NetworkManager 연동

| 기능 | 방법 |
| --- | --- |
| Wi-Fi 켜기·끄기, 목록, 연결, WPA 비밀번호 | Quickshell `Networking`·`WifiNetwork.connect()`/`connectWithPsk()` (기존 경로 그대로) |
| 인터넷 연결 상태 | NetworkManager `Connectivity` (Arch 기본 확인 주소 `http://ping.archlinux.org/nm-check.txt`). «연결됨»과 «인터넷 가능»을 따로 표시 |
| 장치 상세 | `Device`·`Device.Wired`(Speed, Carrier)·`Device.Wireless`·`IP4Config`/`IP6Config`(AddressData, Gateway, NameserverData)·`AccessPoint`(주파수 → 2.4/5/6GHz, 보안 플래그) |
| 저장된 연결 | `Settings.ListConnections` + `GetSettings` (NetworkManager는 이 경로로 비밀번호를 주지 않는다) |
| 프로필 변경 | `Settings.Connection.Update2(TO_DISK)`. 비밀번호를 보내지 않으면 NetworkManager가 기존 비밀번호를 유지한다(시험으로 확인) |
| 연결·해제 | `ActivateConnection`, `Device.Disconnect` |
| 숨겨진 네트워크 | `AddAndActivateConnection` (`802-11-wireless.hidden=true`, 개방/WPA·WPA2/WPA3) |
| 삭제 | `Settings.Connection.Delete` — 대상 이름과 함께 지워지는 것을 확인받은 뒤 |
| 권한 | `GetPermissions`. `auth`이면 polkit이 관리자 비밀번호를 묻는다. 변경 호출은 `ALLOW_INTERACTIVE_AUTHORIZATION` |

`nmcli` 문자열을 해석하지 않는다. 모든 입력은 어댑터가 다시 검증한다: UUID 형식, 인터페이스 이름 형식, `ipaddress` 모듈로 주소·프리픽스·게이트웨이(IPv4는 같은 네트워크인지)·DNS(종류·개수 4개), PAC 주소 형식. 오류는 D-Bus 오류 이름만 화면에 전달하고, 데몬의 오류 문장은 넘기지 않는다.

## 설정 변경과 자동 복원

| 변경 | 보호 방식 | 확인 |
| --- | --- | --- |
| 사용 중인 연결의 IPv4·IPv6·DNS·프록시 | NetworkManager 체크포인트(그 연결의 장치). 적용 직후 30초 확인. «변경 사항 유지» → `CheckpointDestroy`, «이전 설정으로 복원»·무응답 → `CheckpointRollback` | ✅ 시험 환경: 유지, 복원, **어댑터를 강제 종료해도 30초 뒤 NetworkManager가 프로필과 주소를 복원**, 셸 재시작 뒤 남은 대기를 다시 찾아 유지 |
| 사용하지 않는 연결의 IP·DNS | 저장만 한다(연결이 끊길 일이 없음). «다음 연결부터 적용» 안내 | ✅ |
| 자동 연결·우선순위 | 현재 연결에 영향 없음 → 체크포인트 없음 | ✅ |
| 연결 전환·해제·숨겨진 네트워크 연결 | 사용자가 직접 고른 동작이라 체크포인트 없음. 다시 연결로 되돌린다 | ✅(유선) ❓(Wi-Fi) |
| 연결 삭제 | 되돌릴 수 없음 → 대상 이름과 «저장된 비밀번호·IP 설정이 지워짐», 사용 중이면 «연결이 끊어짐»을 보여 주고 확인받음 | ✅ |

체크포인트는 처음에 120초로 만든다(관리자 인증 창을 기다리는 시간). 적용이 끝나면 `CheckpointAdjustRollbackTimeout`으로 30초로 줄인다. 체크포인트는 NetworkManager가 들고 있어서, Shittim·Quickshell이 죽어도 복원은 일어난다. 어댑터는 진행 중인 체크포인트 경로와 프로필 이름만 `$XDG_RUNTIME_DIR/shittim/network-checkpoint`에 둔다(비밀 없음). 셸이 다시 시작되면 이 파일을 보고 남은 시간과 함께 확인 카드를 다시 띄운다.

polkit 인증 창을 누르면 대시보드 패널은 닫힌다(다른 창을 누르면 닫히는 패널 규칙). 이 경우 확인 카드는 `NetworkConfirm`가 모든 모니터 위에 띄운다.

## 진단과 품질

«진단 실행»을 누를 때만 실행한다. 대상은 화면에 적혀 있다.

1. 게이트웨이: `ping -c 4 -I <장치> <게이트웨이>` → 손실률·평균 지연
2. DNS: 장치가 쓰는 DNS 서버(최대 2개)에 확인 주소의 A 레코드를 직접 질의(UDP 53, 링크 로컬 서버는 그 장치로)
3. 인터넷: NetworkManager `CheckConnectivity`(확인 주소로 HTTP) + 확인 주소 `ping -c 5`

품질: **우수** = 인터넷 연결 정상 + 손실 0% + 평균 50 ms 미만, **보통** = 정상 + 손실 10% 이하 + 150 ms 미만, **나쁨** = 그 밖 또는 «제한·포털·없음», **판단 불가** = ping 응답이 없을 때(ICMP 차단 가능). 진단 전에는 «진단 전»이다.

## 보안·개인정보

- Wi-Fi·숨겨진 네트워크 비밀번호는 어댑터 표준입력 → NetworkManager로만 간다. 처리 직후 요청 객체에서 지우고, 출력·로그·파일에 쓰지 않는다(시험으로 확인).
- 상태 출력에 비밀번호가 없다. `GetSettings`가 비밀을 돌려주지 않고, 시험으로도 확인했다.
- 명령은 인자 목록으로만 실행한다(`ping`). 셸을 거치지 않는다.
- 권한을 우회하지 않는다. 시스템 프로필 변경과 체크포인트는 NetworkManager의 polkit 정책(기본 `auth_admin_keep`)을 따른다.

## 참고 저장소

| 저장소 | 확인한 구현 | 반영 |
| --- | --- | --- |
| caelestia-dots/shell (GPL-3.0) | `services/Nmcli.qml`(1,831줄): `nmcli` 인자 목록 실행·terse 출력 파싱·타이머 재확인. `nmcli device wifi connect … password <pw>`로 비밀번호를 명령 인자에 넣음. IPv4만 `nmcli connection modify`로 편집(method/addresses/gateway/dns/ignore-auto-dns). 숨겨진 네트워크·자동 연결·삭제. `modules/nexus/pages/network/*`: 목록·상세·저장됨·유선 상세 페이지 분리. `WirelessPassword.qml` 비밀번호 팝아웃. 트래픽은 C++ 플러그인이 `/proc/net/dev`를 타이머로 읽음 | 탭(Wi-Fi·유선·저장됨)과 상세 분리, 숨겨진 네트워크 입력 항목. 비밀번호를 명령 인자로 넘기는 방식(프로세스 목록에 노출)과 영문 오류 문장 매칭은 따르지 않고 D-Bus를 씀. 체크포인트·IPv6는 caelestia에 없음 |
| 43PR/dotfiles (MIT) | `SettingsPages/NetworkPage.qml`: `nmcli` 프로세스(일부 `sh -c` 파이프라인), `device wifi list` 파싱, `--wait 20 device wifi connect` | 화면 구성만 참고. 셸 파이프라인은 쓰지 않음. IP·DNS 편집 없음 |
| ViegPhunt/Dotfiles (MIT) | `autostart.conf`의 `nm-applet --indicator`, waybar `network` 모듈(SSID·Ethernet 표시) | — |
| ViegPhunt/Arch-Hyprland (MIT) | `install.sh`의 `systemctl enable --now NetworkManager`만 | 설치는 기존 Shittim 방식(다른 네트워크 관리자 실행 중이면 중단) 유지 |

코드는 복사하지 않았다.

## 설치

`scripts/packages.txt`: `networkmanager`, `nm-connection-editor`(기업용 802.1X), `python-dbus-next`, `iputils`(진단 ping) — 모두 공식 저장소. `install-packages.sh`는 다른 네트워크 관리자(systemd-networkd·dhcpcd·iwd·connman)가 돌고 있으면 바꾸지 않고 멈추고, 아니면 NetworkManager를 켠다. 기존 연결 프로필과 비밀번호는 건드리지 않는다. polkit 에이전트는 기존 `run-polkit.sh`.

```bash
bash scripts/verify-network.sh            # 시험 + 실행 중인 NetworkManager 읽기 전용 확인
bash scripts/verify-network.sh --dry-run  # 시험만
```

## 시험

- `tests/test_network_service.py` (15): 주소·프리픽스·게이트웨이·DNS·프록시 검증과 거부 코드, NetworkManager로 보내는 설정 형식(구식 `addresses` 키 제거, DNS 바이트 순서), 프로필 읽기, AP 보안·대역, ping 출력 해석, 품질 기준, DNS 패킷, 잘못된 요청이 D-Bus에 닿지 않음, 비밀번호 비노출, 복원 대기 기록.
- `shell/tests/tst_network.qml` (15): IPv4/IPv6 해석, 편집기 검증, 문구, 진단 문구, Wi-Fi 목록·검색·클릭 연결, 연결된 장치 상세·트래픽, 편집기 검증 후 적용, 유지/복원 카드, 삭제 확인, 유선 탭·장치 없음, 비밀번호 대화상자(표시/숨기기), 진단은 눌렀을 때만, Wi-Fi 하드웨어 차단.
- 실제 NetworkManager 1.58.1 시험 환경(WSL Arch, 별도 네트워크 공간·D-Bus, veth 유선 2개, dnsmasq DHCPv4·RA·DNS, HTTP 연결 확인): 상세 읽기, 잘못된 입력 거부, 수동 IP 적용 → 유지/복원/무응답 복원(어댑터 강제 종료 포함)/재시작 뒤 유지, 자동 연결·우선순위, 비밀번호 유지(저장된 Wi-Fi 프로필), 연결·해제, 삭제, 진단 3단계(링크 로컬 DNS 포함). Quickshell 0.3.2를 화면 없이 띄워 Shittim 서비스와 이 화면으로 같은 흐름을 확인.
- Wi-Fi는 시험 환경에 무선 장치가 없어(WSL 커널에 `mac80211_hwsim` 없음) 실제 연결을 시험하지 못했다.

## 노트북에서 확인할 것

Wi-Fi 목록·대역·연결·비밀번호 오류·숨겨진 네트워크, 하드웨어 스위치, polkit 인증 창이 뜬 뒤 확인 카드가 화면 위에 다시 뜨는지, 유선 꽂기·빼기와 링크 속도, 실제 인터넷에서 진단 값. 원격 접속 중에는 사용 중인 연결의 IP를 바꾸지 않는다(30초 안에 «유지»를 못 누르면 복원되지만, 그동안 접속이 끊길 수 있다).

## 제한

- 기업용 802.1X는 전용 입력 화면이 없다. «기업용(802.1X) 설정 편집기»가 `nm-connection-editor`를 연다.
- NetworkManager는 신호 세기를 %로만 준다. 시안의 dBm 값은 표시하지 않는다.
- 같은 SSID의 여러 AP는 한 줄로 묶고 대역·AP 수만 보여 준다. 특정 BSSID를 골라 연결하지 않는다.
- 수동 IP는 주소 1개(IPv4·IPv6 각각)만 편집한다. 프록시는 NetworkManager가 지원하는 «사용 안 함/자동(PAC)»만.
- 포털(로그인 필요)은 표시만 하고 로그인 브라우저를 열지 않는다.
- 트래픽은 대시보드가 열려 있을 때만 측정한다.
- VPN·핫스팟은 이번 범위가 아니다.
