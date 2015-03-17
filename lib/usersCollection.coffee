#
# This is what a user looks like, from Meteor.users collection:
#

# User:
#   email: email,
#   password: randomPassword, 
#   profile: 
#     name: name,
#     dwollaId: dwollaId,
#     managerId: managerId
#     auth: auth

@userSchema = new SimpleSchema 
  emails:
  	type: [Object]
  	optional: true
  'profile.name':
  	type: String
  	optional: true
  'profile.dwollaId':
  	type: String
  	optional: true
  'profile.managerId':
  	type: String
  	optional: true
  'profile.auth':
  	type: Object
  	optional: true
  'profile.fundingSource':
    type: String
    optional: true
  services:
  	type: Object
  	optional: true
  createdAt:
  	type: Date
  	optional: true
  roles:
	  type: [String]
	  optional: true
	  blackbox: true
	  allowedValues: ['manager', 'accountant', 'employee', 'superAccountant']


Meteor.users.allow
	update: (userId, doc, fields, modifier) ->
		return Roles.userIsInRole userId, ['superAccountant']
