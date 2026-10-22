# 내 스터디 Ready 전환 제안 · SC69

이 브랜치의 stage 변경은 검토용 Draft 제안이다. 배포 QA 증거가 없으므로 머지하거나 기본 ON을 배포하지 않는다. main 및 SC65~68의 플래그는 InProgress·기본 OFF를 유지한다.

선행 조건은 SC68의 최종 앱 root 연결, 같은 배포 환경의 실제 인증·가입 완료 회원·목록·빈 목록·401/403·세션 종료·취소·refresh 경계와 변경 화면 QA다. QA와 head가 해당 환경·커밋·원시 증거를 확인한 뒤 이 제안을 별도로 판단한다. 준비된 PR, Mock/Domain 주입, 로컬 단위 테스트는 이 조건을 충족하지 않는다.

전환 대상 ID는 `study.my-studies`로 같으며 `auth.google-login`과 다른 플래그의 stage는 바꾸지 않는다. 기존 저장된 override는 유지되고 override가 없을 때만 Ready 기본 ON이 적용된다. 안정성 확인 후 플래그 제거는 후속 배포의 별도 작업이다.
