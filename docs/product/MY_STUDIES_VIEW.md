# 내 스터디 LIST View · SC66

SC66은 UIKit 목록과 하드코딩 표시 데이터만 제공한다. SC65 `study.my-studies`가 OFF면 unavailable, ON이면 샘플 두 항목을 표시한다. 공개 탭·프로필·로그인 경로는 연결하지 않으며 실제 참여 정보가 아니다. SC68이 인증과 API를 연결한다. 캘린더·신청·참여 수강 상세 API는 제외한다.

`MyStudiesListViewModel`은 loading/content/empty/failure/guest/unavailable을 구분한다. `update`는 표시 값을 저장한 뒤 private subject로 알린다. 콘텐츠의 중복 ID는 처음 위치와 마지막 표시 값을 유지하고, 선택은 현재 diffable ID를 다시 확인한다. 목록은 기존 StudyCardCell과 AppTheme를 재사용한다. 회원 수를 발명하지 않고 카드 하단에 참여 역할을 표시한다.

empty/failure/content에는 native pull-to-refresh 전달점이 있고 guest에는 명시적 로그인 콜백이 있다. 콜백 미연결 상태에서는 API·인증을 시작하지 않는다. 플래그 OFF와 guest/loading은 refresh를 제공하지 않는다. SC68이 단일 보관 Task와 취소·세션 갱신 정책을 연결한다.

후보별 빌드와 loading/content/empty/failure/guest/unavailable의 신선 Simulator 캡처는 별도 QA·디자인 담당자가 수행한다. View 코드나 하드코딩 렌더가 실제 인증·API·배포 QA를 증명하지 않는다.
