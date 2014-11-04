if Meteor.isClient
  # declare collections:
  Expenses = new Mongo.Collection 'expenses'

  Expenses.attachSchema new SimpleSchema
    title: 
      type: String
      label: 'Title'
      optional: false
      max: 200
    description:
      type: String
      optional: false
      label: 'Description'
      max: 500
    amount: # TODO: consider using cents to store amount
      type: String
      optional: false
      label: 'Amount'
    type:
      type: String
      optional: false
      allowedValues: ['Ground Transportation', 'Office', 'Flights', 'Lodging', 'Food', 'Other']
      label: 'Type'
    date:
      type: Date
      optional: false
      label: 'Date Incurred'
    employeeId:
      optional: false
      type: String
    managerId:
      optional: false
      type: String
    approved:
      optional: false
      defaultValue: false
      type: Boolean
    paid:
      optional: false
      defaultValue: false
      type: Boolean
    paidTransactionId:
      optional: true
      type: String

  # Set AutoForm hooks:

  AutoForm.hooks
    insertExpenseForm:
      before:
        insert: (doc, template) ->  # set employeeId and managerId before inserting document into collection
          doc.employeeId = Meteor.user()._id
          doc.managerId = Meteor.user().profile.managerId
          console.log doc
          return doc
      after:
        insert: (error, result, template) ->
          console.log error, result
      onError: (operation, error, template) ->
        Session.set('insertExpenseFormError', error)

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
        employeeId: Meteor.user()._id


  #
  # Add New Expense Template
  #

  Template.addNewExpense.helpers
    'expenses': () -> Expenses
    'insertError': () -> Session.get('insertExpenseFormError')


# Accounts.createUser({
#   email: email,
#   password: password,
#   profile: {
#     name: 'John Doe',
#     dwollaId: '812-713-9234',
#     managerId: 'efefwef'
#   }  
# })