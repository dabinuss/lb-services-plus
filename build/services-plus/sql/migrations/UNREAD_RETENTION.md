# Unread event retention

`phone_services_plus_unread_events` is intentionally retained without an
automatic age-based cleanup. Each phone/user keeps a persistent high-water
mark in `phone_services_plus_read_state`; deleting events only because they are
old could therefore turn unread counts into an incomplete view for a user who
has not opened the app for a long time.

Before introducing cleanup, add a marker-aware compaction policy that only
removes an event once every relevant reader has advanced beyond it. Until that
policy exists, monitor table growth and do not schedule a generic `DELETE WHERE
created_at < ...` job.
