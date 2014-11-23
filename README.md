# xpenz

Using LESS, coffeescript, Meteor, MongoDB.

## Getting started

Make sure you have meteor installed:

`curl https://install.meteor.com | /bin/sh`

Clone the app and run it with:

`meteor`

## TODO

- implement manager relationship and role
- implement manager expense view, ability to approve or deny an expense
- implement accountant role, 
- implement accountant expense view, ability to pay out groups of approved expenses, ability to approve expenses
- add ability for user, accountant, superAccountant to edit expense
- add status of 'Rejected' and allow manager, superAccountant to reject expenses
- add ability for accountant and superAccount to pay expenses and lump them by category (assume fee by default)
- add confirm or warning when missing receipt
- show expenses that are already reimbursed in collapsed section
- invite new user via email and specify role

Stretch:

- since we want to encourage users to upload a receipt, and the receipt attachment process is the biggest pain point right now (need to click, browse, select, submit), optimize this by starting off with selecting multiple files, then creating a form for each, with the same Trip name.  Step 1: add trip (or choose existing), step 2: select receipt files, step 3: fill out information, submit
- show total reimbursed
- show nice transition animation when expense is approved or denied
- allow undo when deleting expense
- allow undo when approving expense
- allow undo when rejecting expense
- implement accountant statistics view
- implement email alert to manager when expense filed
- implement notifications when your expense got reimbursed or rejected
- implement submit expense by Twilio MMS