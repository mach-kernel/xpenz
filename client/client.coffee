if Meteor.isClient
  # declare collections:
  Expenses = Mongo.Collection('expenses')

  # default session state:
  Session.set 'loginMessage', null

  # Login template:
  Template.login.helpers
    'loginMessage': ->
        Session.get('loginMessage')

  Template.login.events = 'click button': ->
    email = $('#email').val()
    password = $('#password').val()

    Meteor.loginWithPassword(email, password, (error) -> 
      if error
        Session.set 'loginMessage', error.reason
      else
        Session.set 'loginMessage', 'Welcome' + Meteor.user().profile.name
    )

  # Expenses template:


# Accounts.createUser({
#   email: email,
#   password: password,
#   profile: {
#     name: 'John Doe',
#     dwollaID: '812-713-9234'
#   }  
# })