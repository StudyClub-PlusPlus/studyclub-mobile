# UI State Policy

Main and Detail use loading/content/empty/failure. Display values are stored before a private CurrentValueSubject sends a read-only publisher notification. Views read the current values; late subscribers receive the current state. Detail requests once from init through a private method and retains its existing missing/invalid/mismatched-ID empty policy.

## Main list requests

Main starts the first page from init. It also exposes loadMore, retryPage and refresh for infinite scrolling, failed-page retry and native pull-to-refresh. One stored Task owns the current request. Refresh cancels an older request; a cancelled Task must not mutate display values, requestTask or indicators in success, catch or completion. Repeated refresh and concurrent pagination are suppressed. There is no request generation counter or general request framework.

Initial failure replaces the empty list with failure. Normal zero-result first pages are empty. Loading another page keeps content visible; an error keeps the same cursor and shows a retry footer. A zero-length page while offset<total stops automatic pagination and asks for refresh. Refresh keeps existing content until a successful first page replaces it. Failure preserves content and cursor. Successful empty refresh clears items, lookup dictionary and snapshot. Empty/failure still offer the collection's pull gesture.

Responses use the raw item count to advance the cursor. Duplicate IDs within one page fail; repeated IDs across pages update the existing card without changing its position. Main validates identity uniqueness before dictionary creation. Content-to-content notifications must reach the controller, so Main does not remove duplicate status notifications. Changed cards with the same ID are explicitly reconfigured in the diffable snapshot.

## Selection and screen ownership

Selection uses stable diffable Study.ID, never a saved array index. Detail fetches independently. Back navigation retains the list and scroll position. Search owns a separate ViewModel/filter/snapshot and must not replace Main's list. No automatic refresh occurs on Detail return or search cancellation. UIKit/Combine observation and async Repository operations remain separate.
