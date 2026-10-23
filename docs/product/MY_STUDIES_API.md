# 내 스터디 API 계약

`GET /api/me/studies`는 로그인 회원의 참여 스터디와 회차별 출석 정보를 반환한다. 이 문서는 API 계약을 관리한다. 계층·라우터·Repository 구현 규칙은 [아키텍처 문서](../engineering/ARCHITECTURE.md)를 따른다.

## 요청

| 항목 | 값 |
|---|---|
| Method | `GET` |
| Path | `/api/me/studies` |
| 인증 | 필수: `Authorization: Bearer <accessToken>` |
| 기타 헤더 | `Accept: application/json` |
| Query | 없음. 응답 전체를 한 번에 반환하며 페이지네이션을 지원하지 않음 |

요청은 기존 `StudyRouter`와 `StudyAPIClient`를 사용한다. Data는 공백이 아닌 Bearer 토큰만 요청에 넣는다. 토큰과 갱신 정책은 Data 내부 `AuthRepository`가 소유한다.

## 성공 응답 예

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

`meetings`는 스터디 카드의 회차·출석 메타데이터다. 이 응답으로 캘린더나 주간 일정 기능을 만들지 않는다.

## 응답과 화면 처리

| HTTP/결과 | Repository 오류 또는 값 | 화면 동작 |
|---|---|---|
| `200`과 항목 있음 | `[MyStudy]` | content |
| `200`과 빈 배열 | 빈 `[MyStudy]` | empty |
| `401` | `.unauthorized`; 기존 인증 흐름에서 한 번 갱신 후에도 거부되면 세션 무효화 | guest 안내 후 세션 재확인 |
| `403` (`ONBOARDING_REQUIRED`) | `.onboardingRequired` | 가입 정보 확인 안내 후 세션 재확인 |
| `404` | `.notFound` | 일반 실패 |
| `5xx` 또는 전송 실패 | `.unavailable` | 재시도 가능한 실패 |
| 응답 디코딩·매핑 실패 | `.invalidData` | 일반 실패 |
| 취소 | `CancellationError` | 현재 화면 상태를 바꾸지 않음 |

## 매핑 검증

Data 전용 DTO를 Domain의 `MyStudy`와 `MyStudyMeeting`으로 변환한다. `studyId`와 `meetingId`는 양수여야 한다. 제목은 공백을 제거한 뒤 비어 있으면 안 된다. 출석률은 제공된 경우 `0...1`이어야 한다. `sequence`는 1 이상이어야 하며 `scheduledAt`은 필수 UTC timestamp다. 날짜는 문법과 달력 날짜를 확인해 잘못된 날짜를 조용히 보정하지 않는다.

응답 필드를 추측해 추가하지 않는다. 실제 백엔드 기준이 바뀌면 API 계약 원문과 이 문서를 먼저 갱신한다.
