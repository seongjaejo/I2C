# I2C Master / Slave RTL Design & UVM Verification

**FSM 기반 I2C Master·Slave와 UVM 검증 환경을 구현한 프로젝트**입니다. START → 주소/RW → DATA/ACK → STOP 흐름을 transaction으로 묶고, WRITE 수신값과 READ 반환값을 scoreboard에서 비교합니다.

- **언어**: SystemVerilog
- **검증 도구**: Synopsys VCS / UVM 1.2 / Verdi
- **하드웨어 검증 환경**: Basys3 / Saleae Logic Analyzer
- **현재 UVM 조건**: 7비트 주소 `0x27`, 1바이트 전송, READ 후 NACK

[UVM 검증 코드](https://github.com/seongjaejo/I2C/tree/add-i2c-uvm/verification/uvm/i2c) · [테스트 시나리오](https://github.com/seongjaejo/I2C/tree/add-i2c-uvm/verification/uvm/i2c/tb)

> UVM 소스는 `add-i2c-uvm` 브랜치에 업로드되어 있습니다. `main`에서 `verification/uvm/i2c`가 보이지 않으면 위 링크 또는 해당 브랜치를 선택하세요. 아래 UVM 구조·실행 방법은 이 브랜치 기준입니다.

---

## 1. 프로젝트 목표

- START / STOP, 7비트 주소와 R/W, ACK/NACK, 1바이트 READ/WRITE를 구현한다.
- 공유 SDA를 LOW 또는 high-impedance로 구동하는 open-drain 구성을 이해한다.
- 쓰기 결과가 Slave에 전달되고 이후 READ에서 보존되는지 확인한다.
- 버스 구동과 transaction 관찰을 분리하고 데이터·방향별 coverage를 수집한다.

---

## 2. 아키텍처

```text
tb_top
 ├── i2c_if i_if
 ├── i2c_top
 │   ├── i2c_master ── SCL / 공유 SDA ── i2c_slave (주소 0x27)
 │   └── 명령 / ACK / 수신 데이터 / 완료 포트
 └── uvm_test_top
     └── i2c_env
         ├── i2c_agent
         │   ├── sequencer → i2c_driver
         │   └── i2c_monitor → analysis_port
         ├── i2c_scoreboard (마지막 WRITE 값 기억)
         └── i2c_coverage
```

Driver는 한 sequence item마다 START, 주소+R/W, DATA, STOP을 순서대로 수행합니다. Monitor는 `done`의 상승을 검출하고 **4단계 완료를 모아 한 transaction으로 발행**합니다.

---

## 3. 파일 구조

```text
I2C/
├── rtl/                   선정된 코어 / 보드 Master·Slave Top / 공통 모듈
├── constraints/           Master / Slave 제약
├── tb/original/           기존 RTL 테스트벤치
└── verification/
    ├── tb/, evidence/     로컬 코어·보드 구성 테스트 / 결과
    └── uvm/i2c/           서버 검증 당시 RTL / UVM / Makefile
```

```text
verification/uvm/i2c/
├── Makefile
├── rtl/
│   ├── i2c_master.sv
│   ├── i2c_slave.sv
│   └── i2c_top.sv
└── tb/
    ├── i2c_if.sv          interface / clocking block / modport
    ├── i2c_seq_item.sv    transaction과 constraint
    ├── i2c_sequence.sv    directed / random sequence
    ├── i2c_driver.sv      DUT 입력 구동
    ├── i2c_monitor.sv     완료 시점 관찰 / transaction 재구성
    ├── i2c_agent.sv       sequencer / driver / monitor 연결
    ├── i2c_scoreboard.sv  데이터 비교 / pass·fail 집계
    ├── i2c_coverage.sv    functional coverage
    ├── i2c_env.sv         agent / scoreboard / coverage 조립
    ├── i2c_test.sv        test 선택 / objection 관리
    ├── i2c_pkg.sv         class include 순서 관리
    ├── tb_top.sv             clock / DUT / config_db / FSDB
    └── template.sv           보관된 템플릿
```

`template.sv`는 보관 파일이며 현재 package의 include 대상인지와 실제 컴파일 목록은 `pkg.sv` 및 Makefile을 기준으로 확인합니다.

루트의 보드용 RTL과 서버 UVM의 DUT는 별도 묶음입니다. UVM Makefile은 `verification/uvm/i2c/rtl`을 사용합니다.

---

## 4. 검증 시나리오

| 테스트 | 구성 | 확인 항목 |
|---|---|---|
| `i2c_basic_test` | WRITE/READ 3쌍, 총 6건 | 00 → READ, FF → READ, 55 → READ |
| `i2c_random_test` | 700건 | R/W 방향과 WRITE 데이터 랜덤화 |

주소는 `0x27`, READ 시 Master 응답은 `ack_in=1`(NACK)로 제한합니다. `i2c_basic_test`의 `seq.num=200`은 현재 basic sequence에서 반복 횟수로 사용하지 않으므로 실제 고정 시나리오는 6건입니다.

### Scoreboard 비교 기준

| 단계 | 비교 |
|---|---|
| 주소 공통 | Slave 주소 ACK가 0인지 확인 |
| WRITE | 데이터 ACK=0 및 `slave_rx_data === wdata` |
| READ | `rdata === last_write_data`; WRITE 전이면 RESET_DATA=`0xA5` |

전체 메모리 모델 대신 **1바이트 저장 레지스터의 마지막 WRITE 값**을 기억하는 방식입니다.

---

## 5. 핵심 구현과 커버리지

| 구현 | 의도 |
|---|---|
| START / WRITE / READ / STOP task 분리 | 명령 완료 단위로 구동 순서를 관리 |
| done 상승 검출 + 단계 카운트 | 한 단계가 여러 번 집계되는 것을 피하고 transaction 경계를 정의 |
| 마지막 WRITE 값 저장 | 랜덤 READ에서도 기대값을 결정 |
| READ 이전 RESET_DATA 비교 | 초기값 읽기 시나리오의 기대값 정의 |
| R/W별 coverage sampling | WRITE에서 wdata, READ에서 rdata만 측정 |

| Coverpoint | Bin / 샘플 조건 |
|---|---|
| WRITE data | 00 / FF / 01~FE, WRITE일 때만 |
| READ data | 00 / FF / 01~FE, READ일 때만 |
| R/W | WRITE / READ |

ACK-in coverpoint와 cross는 현재 주석 처리되어 있습니다. 주소·응답 지연·repeated START·오류 주소는 현재 covergroup의 측정 대상이 아닙니다.

---

## 6. 검증 결과와 확인 범위

| 구분 | 결과 / 기준 |
|---|---|
| 기존 서버 UVM 검증 기록 | 랜덤 700건, functional coverage 100% (포트폴리오 기준) |
| 기존 실보드 검증 기록 | Basys3 및 Saleae로 I2C 동작 확인 |
| 저장소 정리 시 로컬 RTL 재검증 | 통합 코어 WRITE/READ 16쌍, 보드 Top 구성 4쌍, 오류 0 |

서버 UVM 결과는 기존 포트폴리오에 기록한 결과입니다. 현재 업로드에는 VCS 실행 원본 로그와 functional coverage 보고서가 포함되어 있지 않아, 이 문서 정리 과정에서 해당 수치를 다시 실행·확인한 결과로 표기하지 않았습니다. 아래 실행 명령으로 재현한 뒤 scoreboard 처리 건수, fail count, UVM_ERROR/FATAL 및 coverage report를 함께 확인할 수 있습니다.

Functional coverage 100%는 **현재 정의한 bin을 모두 hit했다는 의미**입니다. 코드 커버리지 100% 또는 프로토콜 전체 검증 완료와는 구분합니다. `verification/evidence/`의 로컬 테스트 기록도 VCS UVM 실행 결과와 별도로 관리합니다.

---

## 7. 실행 방법

VCS / UVM 1.2 / Verdi 및 FSDB 연동 환경이 필요합니다. 업로드된 Makefile에는 GNU Make 주석이 아닌 `//TEST` 줄이 있어, 원본을 유지한 실행용 Makefile을 먼저 만듭니다.

```sh
git switch add-i2c-uvm
cd verification/uvm/i2c
sed 's@^//TEST@#TEST@' Makefile > /tmp/i2c-uvm.Makefile
make -f /tmp/i2c-uvm.Makefile run TEST=i2c_basic_test INFO_LEVEL=UVM_MEDIUM
make -f /tmp/i2c-uvm.Makefile run TEST=i2c_random_test SEED=1234 INFO_LEVEL=UVM_MEDIUM
verdi -dbdir ./simv.daidir -ssf i2c_tb.fsdb
```

Makefile의 wave target에도 `//` 주석이 있어 위 Verdi 명령을 직접 사용합니다. 실행별 로그와 coverage DB를 보관한 뒤 결과를 비교합니다.

별도의 로컬 RTL 테스트는 저장소 루트에서 `python verification/run_checks.py`로 실행합니다. 이 테스트는 VCS UVM과 구분하며, 보드 프로젝트에서는 해당 Master/Slave 제약 파일을 각각 선택합니다.

---

## 8. 검증 범위와 향후 확장

- 현재 UVM은 일치하는 주소의 정상 1바이트 READ/WRITE를 중심으로 검증합니다.
- 주소 불일치 NACK, repeated START, multi-byte, clock stretching, reset 중단과 timeout을 확장할 수 있습니다.
- ACK/NACK 및 R/W cross를 확장할 때는 현재 constraint가 허용하는 값과 bin 범위를 함께 조정해야 합니다.
- done 4단계 카운트는 현재 driver의 명령 흐름을 전제로 합니다. 오류 중단·재시도 시나리오를 추가할 때는 monitor의 재동기화도 필요합니다.
- Scoreboard의 bit 기반 관찰 필드는 X/Z 검출을 대신하지 않으므로, 별도 protocol/X assertion을 추가할 수 있습니다.

원본 선택 및 로컬 확인 이력은 [SELECTION_AND_VALIDATION.md](SELECTION_AND_VALIDATION.md), 파일 출처는 [SOURCE_MANIFEST.json](SOURCE_MANIFEST.json)에 기록했습니다.
