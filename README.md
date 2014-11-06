# xpenz

Using LESS, coffeescript, Meteor, MongoDB.

## Getting started

Make sure you have meteor installed:

`curl https://install.meteor.com | /bin/sh`

Clone the app and run it with:

`meteor`

## TODO

- implement image upload
- implement manager relationship and role
- implement manager expense view, ability to approve or deny an expense
- implement accountant role, 
- implement accountant expense view, ability to pay out groups of approved expenses, ability to approve expenses
- add ability for user, accountant, superAccountant to edit expense
- add ability to OAuth to login
- add status of 'Rejected' and allow manager, superAccountant to reject expenses
- add ability to store access token and refresh token for user
- add ability for accountant and superAccount to pay expenses and lump them by category (assume fee by default)
- add confirm or warning when missing receipt
- hide the expenses that are already reimbursed

Stretch:

- show total reimbursed

- allow undo when deleting expense
- allow undo when approving expense
- allow undo when rejecting expense
- implement accountant statistics view
- implement email alert to manager when expense filed
- implement submit expense by Twilio MMS