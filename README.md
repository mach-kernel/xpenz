# xpenz

Using LESS, coffeescript, Meteor, MongoDB.

## Getting started

Make sure you have meteor installed:

`curl https://install.meteor.com | /bin/sh`

### Required Settings

You will need:

- S3 bucket
- Dwolla API key/secret

##### run.sh
```
#/bin/bash

# AWS Config
export XPENZ_S3_KEY="this thing"
export XPENZ_S3_SECRET="that thing"
export XPENZ_S3_BUCKET="the other thing"

# Dwolla Config
export DWOLLA_KEY="wat"
export DWOLLA_SECRET="sshhhh"

# Custom Domain
export ROOT_URL="http://localhost:3000"

# Mail Functionality
export MAIL_URL="smtp://your_username:your_password@smtp.yourserver.net:587"

meteor
```

### E-Mail Notifications

In order for e-mail notifications to work, you must set a valid SMTP host to send mail through. If mail flow does not work even with a valid SMTP host, it is probably because you are not running xpenz from a box with a static IP or valid reverse-dns lookup. You can verify this via [MxToolbox's reverse lookup utility](http://mxtoolbox.com/ReverseLookup.aspx).

### Running

Clone the app and run it with:

`chmod +x runapp.sh && ./runapp.sh`

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
- implement submit expense by Twilio MMS
- create Organization collection with access token of dwolla account to pay from.  Employees have an Organization ID, and accountants and managers can only interact with employees of their organization
- auth using Google instead of Dwolla.  Only accountants need Dwolla -- let them connect their account.
