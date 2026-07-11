# Rider Delivery State Contract

The Rider app consumes the existing `deliveryRequests` state contract through
the trusted `updateDeliveryTrackingStatus` callable. Flutter never owns the
authoritative delivery state.

| Rider action | Canonical backend state |
| --- | --- |
| Accept offer | `accepted` |
| Start route to pickup | `navigating_to_pickup` |
| Arrive at pickup | `arrived_at_pickup` |
| Verify collection | `pickup_verified` |
| Start delivery | `navigating_to_dropoff` |
| Arrive at drop-off | `arrived_at_dropoff` |
| Verify recipient | `delivered` |
| Report issue | `issue_reported` |

Legacy aliases are normalised by `RiderDeliveryStagePolicy` for presentation.
The callable enforces authenticated rider ownership, account eligibility,
allowed transitions, server timestamps, idempotent terminal retries, and PIN
attempt limits. Waiting and no-show remain governed by the existing
`recordRiderArrival` and `markRiderNoShow` delivery-policy callables.
