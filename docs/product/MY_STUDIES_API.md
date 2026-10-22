# 내 스터디 목록 (My Studies) API 명세 및 iOS 연동 계약

- 작업 단위: SC67 API Slice
- 브랜치: `junsu/sc-67`
- 백엔드 기준 커밋: `a38aa64b` (`specs/my-studies/spec.md`, `ParticipantHubController.java`, `ParticipantHubResponses.java`)

---

## 1. 개요

로그인한 회원이 참여 중인 스터디 목록과 각 스터디의 회차별 출석 정보를 조회하는 `GET /api/me/studies` 엔드포인트 연동 명세입니다.
- **서버 무페이징**: 본 API는 쿼리 파라미터 기반 페이징을 지원하지 않으며, 단일 호출로 회원이 참여한 모든 스터디 배열(`items`)을 반환합니다.
- **캘린더 확장 배제**: 응답에 포함된 `meetings` 배열은 카드의 다음 회차 안내 및 출석률 산정 등 메타데이터 표시에만 사용되며, 캘린더나 주간 일정 뷰로 확장하지 않습니다.
- **인증 보호**: private endpoint이므로 `MyStudiesRouter` 및 `MyStudiesAPIClient`는 nonoptional `accessToken: String`을 요구하며, 빈 값이나 공백 문자열 전달 시 네트워크 호출 전에 `.unauthorized` 에러를 발생시켜 무인증 요청을 원천 차단합니다.

---

## 2. API 상세 명세

### 기본 정보
- **Method**: `GET`
- **Path**: `/api/me/studies`
- **인증(Auth)**: 필수 (`Bearer <accessToken>`, 백엔드 `@RequireOnboarding` 적용)
- **Headers**:
  - `Accept: application/json`
  - `Authorization: Bearer <accessToken>`

### Response Body (200 OK)
```json
{
  "items": [
    {
      "studyId": 12,
      "title": "DDIA 2판 수요일반",
      "category": "SOFTWARE",
      "studyKind": "STUDY",
      "startAt": "2026-09-01T00:00:00Z",
      "endAt": "2026-11-10T00:00:00Z",
      "relation": "ONGOING",
      "participantStatus": "ACTIVE",
      "participantRole": "LEADER",
      "discordChannelUrl": "https://discord.com/channels/...",
      "driveUrl": "https://drive.google.com/...",
      "attendanceRate": 0.83,
      "meetings": [
        {
          "meetingId": 301,
          "sequence": 1,
          "scheduledAt": "2026-09-02T11:00:00Z",
          "startAt": "2026-09-02T11:02:00Z",
          "endAt": "2026-09-02T12:30:00Z",
          "attendanceStatus": "PRESENT",
          "countedInRate": true
        }
      ]
    }
  ]
}
```

### 상태 코드 및 에러 처리
| HTTP Status | 에러 원인 | 클라이언트 매핑 (`MyStudiesError`) | UI 반영 |
|---|---|---|---|
| **200 OK** | 정상 조회 | Domain `[MyStudy]` 반환 | `content` (0건 시 `empty`) |
| **401 Unauthorized** | 토큰 누락 또는 만료 | `.unauthorized` | 비로그인 게이트 (`authGate`) 또는 재인증 |
| **403 Forbidden** | 온보딩 미완료 (`ONBOARDING_REQUIRED`) | `.onboardingRequired` | 가입/온보딩 완료 유도 |
| **404 Not Found** | 리소스 없음 (본 API에서 정상적인 404 경로 없음) | `.unavailable` (별도 notFound 도메인 케이스 미제공) | 일반 실패 상태 (`failure`) |
| **5xx / Network** | 서버 또는 전송 실패 | `.unavailable` | 재시도 가능한 실패 상태 (`failure`) |
| **Decoding Failure** | 스펙 불일치 응답 | `.invalidData` | 일반 실패 상태 (`failure`) |

---

## 3. iOS 계층별 구현 및 책임 경계

### 3.1 Domain 계층 (`Domain/Models/MyStudy.swift`, `Domain/Repositories/MyStudiesRepository.swift`)
- **타입 정의**:
  - `MyStudy`: `Identifiable`, `Hashable`, `Sendable` 준수. 식별자는 기존 `Study.ID`(`String`)를 재사용.
  - `MyStudyMeeting`: 회차 및 출석 여부 메타데이터.
  - Typed Enums: `MyStudyRelation`, `ParticipantRole`, `ParticipantStatus`, `AttendanceStatus`.
- **리포지토리 프로토콜**:
  - `MyStudiesRepository`: `func fetchMyStudies() async throws -> [MyStudy]`
  - 프로토콜 명칭은 프로젝트 컨벤션(`MyStudiesRepository`) 준수.
  - 토큰 인자 없음: Domain 계층은 인증 토큰에 의존하지 않으며, 실제 인증 세션 주입은 SC68에서 Data 계층 내부 결합.
  - `MyStudiesError`: `unauthorized`, `onboardingRequired`, `featureUnavailable`, `unavailable`, `invalidData`.

### 3.2 Data 계층 (`Data/DTO/`, `Data/Mappers/`, `Data/Network/`)
- **DTO**:
  - `MyStudyListResponseDTO`, `MyStudyDTO`, `MyStudyMeetingDTO` 정의.
  - Data 계층 내부에서만 접근 가능 (`toDomain()`을 통해 매핑).
- **검증 규칙 (`MyStudyMapper`)**:
  - `studyId > 0`: 0 이하의 ID는 `.invalidData` 오류 발생.
  - `title`: 공백 제외 1글자 이상 필수.
  - `attendanceRate`: 존재 시 `0.0 <= rate <= 1.0` 범위 검증.
  - 날짜 파싱: Lexical regex + Calendar round-trip 검증 (정규화로 인한 잘못된 달력 날짜 수용 방지).
  - `meetingId > 0`, `sequence >= 1`, `scheduledAt` 필수 검증.
- **네트워크 (`MyStudiesRouter`, `MyStudiesAPIClient`)**:
  - `MyStudiesRouter`: `/api/me/studies` URLRequest 생성. nonoptional `accessToken` 전달받아 Bearer 헤더 주입. 빈 문자열 전달 시 즉시 `.unauthorized` 반환.
  - `MyStudiesAPIClient`: Swift Concurrency 기반 Alamofire 요청 및 에러 매핑(`mapError`). URLSession `URLError.cancelled` 및 `AFError.sessionTaskFailed` underlying 취소 에러를 `CancellationError`로 보존.

---

## 4. 작업 및 의존성 규칙

1. **기존 소스 보호**: `RepositoryFactory`, `Auth`, `View`, `FeatureFlag` 수정 없음.
2. **빌드 및 테스트 규칙**: QA 소유의 build/Simulator lease를 준수하여 빌드/시뮬레이터 조작을 하지 않으며, 매퍼 및 에러 분류 단위 테스트(`MyStudyMapperTests`, `MyStudiesErrorTests`)는 정적/직접 검증으로 구현.
3. **통합 계획 (SC68)**: 개발 리드가 `DefaultAuthRepository`와 세션 수명주기를 결합하고 concrete Repository를 제공할 때까지 concrete Real Repository 생성을 유예함.
