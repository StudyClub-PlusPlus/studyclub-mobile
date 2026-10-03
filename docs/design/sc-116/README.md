# sc-116 AS-IS / TO-BE 화면 비교

AS-IS는 main 기준 커밋 `c2fea74614f96210f8b9c01e32a12b389d7e84c9`, TO-BE는 구현 커밋 `d0bb465051466de9043c5bba0f61744807bfc9b6`의 UIKit 화면이다. 같은 iPhone 17 Pro / iOS 26.5, 기본 글자 크기, 라이트 모드에서 같은 Domain 샘플을 공급해 2026-10-03에 캡처했다.

임시 앱으로 실제 Main/Detail controller와 ViewModel의 기존 Repository 테스트 initializer를 렌더했다. 비교 host는 양쪽 모두 라이트로 고정했다. 운영 API 응답, 원래 앱의 화면 이동 또는 AS-IS의 다크 모드 동작을 재현한 사진은 아니다. status bar의 OS가 표시하는 이전 앱 링크는 제품 변경에 해당하지 않는다. 임시 앱과 컴파일 소스는 제품 target에 추가하지 않았다.

| 화면 | AS-IS | TO-BE |
| --- | --- | --- |
| 목록 | ![AS-IS 목록](asis-main.png) | ![TO-BE 목록](tobe-main.png) |
| 상세 | ![AS-IS 상세](asis-detail.png) | ![TO-BE 상세](tobe-detail.png) |
| 일정·본문·커리큘럼이 없는 상세 | ![AS-IS 빈 섹션](asis-detail-empty-sections.png) | ![TO-BE 빈 섹션](tobe-detail-empty-sections.png) |

목록·상세 일반 표본은 기존 Mock의 제목/소개/멤버/모집 상태를 Domain 값으로 공급했다. 세 번째 표본은 빈 optional 조합을 명시적으로 공급했다. 실제 앱의 light-only, selection/back/tab 및 상태 렌더 검토는 별도 수행했으며, 이 여섯 사진만으로 전체 QA나 API 성공을 주장하지 않는다.
