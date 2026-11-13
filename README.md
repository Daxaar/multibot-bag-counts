# MultiBot Bag Counts

Copy this folder to the Wrath client's Interface/AddOns directory, fully reopen WoW, and enable MultiBot Bag Counts. Requires the existing MultiBot Bridge with ALT_ROSTER and INVENTORY_EXACT support. Log in your managed alts as bots and hover your own bag items. Close and reopen a tooltip to read refreshed counts.

Only online same-account alts that pass the bridge's local inventory authorization are included. The first hover starts a scan if no recent snapshot is available. Other hovers reuse that snapshot until all bags close. Reopening within 10 seconds of a completed scan reuses it for the new session. Close and reopen the bags after that window for fresh counts. No bridge rebuild or database update is required.
