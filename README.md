# MultiBot Bag Counts

Shows an inventory count for alt bots (typically those you are in the same party with) similar to how inventory addons such as ArkInventory do in an items tooltip. Useful for seeing how many of a given quest item a bot has looted or if you're just looking for who you can steal something from!

Clone the source into the `Multibot Bag Counts` folder in the Wrath client's `Interface/AddOns` directory. Requires the existing MultiBot Bridge with ALT_ROSTER and INVENTORY_EXACT support. Log in your managed alts as bots and hover your own bag items. Close and reopen a tooltip to read refreshed counts.

Only online same-account alts that pass the bridge's local inventory authorization are included. The first hover starts a scan if no recent snapshot is available. Other hovers reuse that snapshot until all bags close. Reopening within 10 seconds of a completed scan reuses it for the new session. Close and reopen the bags after that window for fresh counts. No bridge rebuild or database update is required.

<img width="512" height="214" alt="image" src="https://github.com/user-attachments/assets/69f65128-27af-455d-a712-5b89a261ad1c" />
