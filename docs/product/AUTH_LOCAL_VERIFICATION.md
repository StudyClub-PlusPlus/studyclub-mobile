# Debug Mock 가입 검증 · SC73

[작업73](https://app.notion.com/p/benkang/8768d232c6b145ba9d194f7c4050e581)은 Google 설정 없이 로그인·가입·설정과 회원 영역을 시험할 수 있도록 한다. 기존 구현을 재사용하며 새 인증 API나 세션 저장소를 추가하지 않는다.

Debug 개발 설정에서 Mock을 선택하고 `auth.google-login`을 켠다. `account.mypage`·`study.my-studies`를 함께 켜면 프로필과 내 스터디에서도 같은 계정 흐름을 확인할 수 있다. `auth.google-login`과 `account.mypage`는 Ready이고 `study.my-studies`는 InProgress다. 일반 Debug/Release의 기본값은 각각 ON과 OFF이고 STAGE는 모두 ON이다. 저장 override가 우선한다. Mock/Real 변경은 기존 탭 재구성 경로를 따른다.

Mock 로그인은 기존 신규가입 분기를 연다. 로그인 화면과 가입 화면에 짧은 테스트 안내가 있다. 필수·선택 동의는 모두 OFF로 시작하며 필수 동의와 닉네임이 있어야 제출한다. 약관 원문은 기존 문서 버튼으로 읽는다. 이 동의는 실제 약관 승인이나 서버 가입 기록이 아니다.

Mock 가입과 로그아웃은 현재 Repository 메모리에 반영한다. 개발 설정의 비회원/회원 선택은 새 Repository의 시작 상태를 정하고 재실행 후에도 유지한다. 가입 입력과 동의를 재실행 후 복원하지 않는다. 실제 Keychain과 Google 계정은 사용하지 않는다.

Factory가 선택한 실제 구성의 Mock 여부를 화면까지 전달한다. Real은 설정이 없으면 Google 인증을 시작하지 않고 미제공 상태를 표시한다. 현재 Real과 Release는 웹 약관·개인정보 페이지를 연결하고 동의·제출을 허용한다. 이는 법적 승인 확인이 아니다. Release는 저장된 Mock 설정을 무시하고 Real을 구성한다.

[외부 설정 이슈172](https://app.notion.com/p/benkang/c833f839ac2d4a8fb011e22f2dce6164)는 실제 client ID·URL scheme·서버 설정·실제 회원 검증·현재 약관 승인 자료를 맡는다. 기존 SC54 조사와 SC53 Ready 판단을 연결한다. 로컬 검증 완료가 이 외부 이슈나 SC69 Ready 완료를 뜻하지 않는다.
