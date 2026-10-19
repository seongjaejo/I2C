# I2C Master / Slave

선정 원본: `D:\OndeviceAI2\260612_I2C_Master + 260612_I2C_board_master + 230612_I2C_board_slave`

Top: `i2c_master_board_top / i2c_slave_board_top`

원본에서 누락된 공통 의존성을 함께 포함했습니다. Master/Slave 제약을 동시에 등록하지 않습니다.

선정 근거와 실제 테스트 범위·알려진 제한은 [검증 기록](SELECTION_AND_VALIDATION.md)을 확인하세요.

## 검증 실행

Icarus Verilog 13과 Python이 필요합니다. 저장소 루트에서 실행합니다.

```sh
python verification/run_checks.py
```

실행한 테스트와 로그는 `verification/`에 있습니다. 실물 보드 재시험·합성·타이밍 검증 완료를 의미하지 않습니다.
