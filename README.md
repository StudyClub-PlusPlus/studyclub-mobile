# StudyClub Mobile

StudyClub의 네이티브 모바일 앱 모노레포입니다. 현재는 iOS 기반 구조와 Main → Detail 예제 흐름을 먼저 검증하며, Android는 이 제품 계약을 기준으로 이후 네이티브 구현합니다.

## Repository

- `ios/`: UIKit iOS 애플리케이션과 테스트
- `docs/engineering/`: 아키텍처와 공통 개발 정책
- `docs/product/`: 플랫폼 공통 화면·상태 계약
- `AGENTS.md`: AI 작업자가 가장 먼저 읽어야 할 규칙
- `DESIGN.md`: 현재 UI 디자인 시스템과 검증 기준

## iOS baseline

- UIKit + programmatic Auto Layout
- MVVM + Repository
- Swift Concurrency for asynchronous work
- Combine for ViewModel → View binding only
- Diffable Data Source + Compositional Layout
- Alamofire adapter boundary and deterministic mock data

Open `ios/studyclub.xcodeproj` and run the `studyclub` scheme.
