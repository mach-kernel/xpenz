# xpenz

Using LESS, coffeescript, Meteor, MongoDB.

## Getting started

Make sure you have meteor installed:

`curl https://install.meteor.com | /bin/sh`

You'll need an S3 bucket and credentials.  Set the following environment variables:

```
XPENZ_S3_KEY={ s3 key }
XPENZ_S3_SECRET= { s3 secret }
XPENZ_S3_BUCKET= { s3 bucket name }
```

Clone the app and run it with:

`meteor`

## TODO

- add ability for user, accountant, superAccountant to edit expense
- add ability to change funding source for accountant and superAccountant

Stretch:

- since we want to encourage users to upload a receipt, and the receipt attachment process is the biggest pain point right now (need to click, browse, select, submit), optimize this by starting off with selecting multiple files, then creating a form for each, with the same Trip name.  Step 1: add trip (or choose existing), step 2: select receipt files, step 3: fill out information, submit
- show total reimbursed
- show expenses that are already reimbursed in collapsed section
- show nice transition animation when expense is approved or denied
- allow undo when deleting expense
- allow undo when approving expense
- allow undo when rejecting expense
- implement accountant statistics view
- implement email alert to manager when expense filed
- implement notifications when your expense got reimbursed or rejected
- implement submit expense by Twilio MMS
- create Organization collection with access token of dwolla account to pay from.  Employees have an Organization ID, and accountants and managers can only interact with employees of their organization
- auth using Google instead of Dwolla.  Only accountants need Dwolla -- let them connect their account.