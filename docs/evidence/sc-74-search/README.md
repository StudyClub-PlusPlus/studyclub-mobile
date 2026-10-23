# SC74 검색 플래그 · 2026-10-23

- 실행 source: `d0431ecc9d99f8420dc2bf03fc13a5905cd241eb`, app source tree `a66267ff9d8f88179111ac8c1def53d657140226`. 이후 이 증거 문서·이미지만 추가한다.
- Xcode27.0(27A266a), Debug, generic iOS Simulator build exit0. 전용 DerivedData는 `/tmp/studyclub-search-r1/DerivedData`다.
- 재사용 기기: iPhone17e / iOS26.5 / `8F5597F4-5B0C-41C9-8994-8FEAB62CBBE1`. 다른 작업이 사용 중인 iPhone17Pro는 조작하지 않았다.
- bundle: `studycub.studyclub`. 설치한 Debug app의 `studyclub.debug.dylib` SHA256: `e3918dc211b531cf0fa9a39e08d8a35d80e3fa67f059b5fccebea2579c29cec7`.
- 기존 Real 모드로 Main을 실행하고 native Main 탭을 0.9초 눌러 Development Settings를 열었다. InProgress에 검색 스위치 OFF, 기존 목록·상세·디자인 Ready ON을 확인했다. 검색 플래그를 변경하지 않았다.
- [실제 기기 캡처](development-settings-off.png). 이 후보의 안내는 “화면 재진입”이며, SC76에서 실제 고정 시점에 맞게 “앱 재실행”으로 수정한다.

이 작업은 catalog 등록만 한다. 검색 UI·API·Ready 전환·배포별 검색 QA는 이 증거의 범위가 아니다. 내부 설정 자동 테스트는 추가하지 않았다.
