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
    paidTransactionId:
      optional: true
      type: String
    status:
      type: String
      optional: false
      allowedValues: ['PendingApproval', 'PendingReimbursement', 'Rejected', 'Reimbursed']

  # Set AutoForm hooks:

  AutoForm.hooks
    insertExpenseForm:
      before:
        insert: (doc, template) ->  # set employeeId and managerId before inserting document into collection
          doc.employeeId = Meteor.user()._id
          doc.managerId = Meteor.user().profile.managerId
          doc.status = 'PendingApproval'
          console.log doc
          return doc
      after:
        insert: (error, result, template) ->
          console.log error, result
      onError: (operation, error, template) ->
        Session.set('insertExpenseFormError', error.message)

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
    'expensesCollection': () -> Expenses

  #
  # Add New Expense Template
  #

  Template.addNewExpense.rendered = () ->
    Session.set('insertExpenseFormError', null)

  Template.addNewExpense.helpers
    'expenses': () -> Expenses
    'insertError': () -> Session.get('insertExpenseFormError')


# Accounts.createUser({
#   email: email,
#   password: password,
#   profile: {
#     name: 'John Doe',
#     dwollaId: '812-713-9234',
#     managerId: 'efefwef',
#     canApproveExpenses: false,
#     canApproveOwnExpenses: false,
#     canReimburseExpenses: false,
#     emailAddress: null,
#     
#   }  
# })