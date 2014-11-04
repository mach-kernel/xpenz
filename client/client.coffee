if Meteor.isClient
  # declare collections:
  Expenses = new Mongo.Collection('expenses')

  # default session state:
  Session.set 'loginMessage', null

  # 
  # Login template
  #

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

  #
  # Expenses Template
  #

  Template.showExpenses.helpers
    'getExpenses': () -> 
      Expenses.find
        employee: Meteor.user()._id


  #
  # Add New Expense Template
  #

  Template.addNewExpense.events =
    'click button': ->
      expenseTitle = $('#expenseTitle').val()
      expenseDescription = $('#expenseDescription').val()
      expenseAmount = $('#expenseAmount').val()
      expenseDate = $('#expenseDate').val()
      expenseType = $('#expenseType').val()
      # TODO: set manager here

      # TODO: handle validation here

      Expenses.insert
          title: expenseTitle
          description: expenseDescription
          amount: expenseAmount
          date: new Date(expenseDate)
          type: expenseType
          employee: Meteor.user()._id
        , (error, id) -> console.log error, id

# Accounts.createUser({
#   email: email,
#   password: password,
#   profile: {
#     name: 'John Doe',
#     dwollaID: '812-713-9234',
#     manager: 'brent@dwolla.com'
#   }  
# })