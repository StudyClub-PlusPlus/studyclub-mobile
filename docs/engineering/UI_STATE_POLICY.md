# UI State Policy

Main uses loading/content/empty/failure/unavailable; Detail keeps loading/content/empty/failure. Main unavailable means the feature is not provided, rather than an empty response or request failure. Display values are stored before a private CurrentValueSubject sends a read-only publisher notification. Views read the current values; late subscribers receive the current state. Detail requests once from init through a private method and retains its existing missing/invalid/mismatched-ID empty policy.

## Main list requests

Main captures the list flag at creation. The pagination/refresh rules below apply to ON. OFF requests once, disables refresh/loadMore/retryPage, omits the footer and refresh control, and hides collection content behind a state surface. Debug Mock shows its current trusted first-page samples. Real OFF returns featureUnavailable before transport, clears selection and ends loading with unavailable. Real detail OFF returns unavailable before transport and preserves its existing failure state; Mock detail and detail behavior are independent of the list flag.

Main starts the first page from init. It also exposes loadMore, retryPage and refresh for infinite scrolling, failed-page retry and native pull-to-refresh. One stored Task owns the current request. Refresh cancels an older request; a cancelled Task must not mutate display values, requestTask or indicators in success, catch or completion. Repeated refresh and concurrent pagination are suppressed. There is no request generation counter or general request framework.

Initial failure replaces the empty list with failure. Normal zero-result first pages are empty. Loading another page keeps content visible; an error keeps the same cursor and shows a retry footer. A zero-length page while offset<total stops automatic pagination and asks for refresh. Refresh keeps existing content until a successful first page replaces it. Failure preserves content and cursor. Successful empty refresh clears items, lookup dictionary and snapshot. Empty/failure still offer the collection's pull gesture.

Responses use the raw item count to advance the cursor. Main merges IDs while storing each page: duplicates within or across pages keep their first position and receive the last value. Initial load and successful refresh clear the previous list before using the same merge path. No separate duplicate validation is needed; snapshots receive the resulting unique IDs. Content-to-content notifications must reach the controller, so Main does not remove duplicate status notifications. Changed cards with the same ID are explicitly reconfigured in the diffable snapshot. The controller applies snapshots only when IDs, their order or card values change (plus initial section setup). Loading/error indicators update independently. An unchanged successful page still checks whether another page is needed, since its raw cursor may have advanced.

## Selection and screen ownership

Selection uses stable diffable Study.ID, never a saved array index. Detail fetches independently. Back navigation retains the list and scroll position. Search owns a separate ViewModel/filter/snapshot and must not replace Main's list. No automatic refresh occurs on Detail return or search cancellation. UIKit/Combine observation and async Repository operations remain separate.

## MyPage

Guest/loading/content/failure/expired are exclusive. The root-owned model requests once for an initial session and again only for explicit Mock demo entry. One retained Task is cancelled before logout clears repository/session/display fields; cancelled success and errors cannot restore identity. Unauthorized clears the session, ordinary failure preserves the session for logout. No retry or refresh is added.
