if Meteor.isClient
  Expenses = new Mongo.Collection 'expenses'

  Expenses.attachSchema new SimpleSchema
    vendor: 
      type: String
      label: 'Who was paid?'
      optional: false
      max: 200
    description:
      type: String
      optional: false
      label: 'Description'
      max: 500
    trip:
      type: String
      optional: true
      label: 'Trip'
      max: 500
    amount: # TODO: consider using cents to store amount
      type: String
      optional: false
      label: 'Amount'
    type:
      type: String
      optional: false
      allowedValues: ['Ground Transportation', 'Office Supplies', 'Flights', 'Lodging', 'Food', 'Other']
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
    receiptFileURL:
      type: String
      optional: true

  # TODO: validate each potential expense object on the server side
  Meteor.subscribe "expensesCreatedByUser"
  
  console.log 'hopefully we got expensive before clients'

  # default session state:
  Session.set 'loginMessage', null

  Template.registerHelper 'isSuperAccountant', () ->
    return Roles.userIsInRole Meteor.user()._id, 'superAccountant'

  # 
  # Login template
  #

  Template.login.helpers
    'loginMessage': ->
        Session.get('loginMessage')

  Template.login.events = 'click button, keydown': (e) ->
    # ignore any non-enter keystrokes...
    if (e.type == 'keydown' && e.which != 13) 
      return

    email = $('#email').val()
    password = $('#password').val()

    Meteor.loginWithPassword(email, password, (error) -> 
      if error
        Session.set 'loginMessage', error.reason
      else
        Session.set 'loginMessage', 'Welcome' + Meteor.user().profile.name
    )

  #
  # Welcome Template
  #

  Template.welcome.events = 
    'click #logoutButton': () ->
      Meteor.logout()

  #
  # showUserExpenses template
  #

  Template.showUserExpenses.helpers
    'getExpenses': () -> 
      Expenses.find
        employeeId: Meteor.user()._id
    'expensesCollection': () -> Expenses

  Template.showUserExpenses.rendered = () ->
    if Roles.userIsInRole Meteor.user()._id, 'superAccountant'
      Meteor.subscribe "expensesAllPendingApproval"
      Meteor.subscribe "expensesAllPendingReimbursement"
      Meteor.subscribe "allUsers"

    if Roles.userIsInRole Meteor.user()._id, 'accountant'
      Meteor.subscribe "expensesAllPendingReimbursement"
      Meteor.subscribe "allUsers"

    if Roles.userIsInRole Meteor.user()._id, 'manager'
      Meteor.subscribe "expensesWhichRequireManagerApproval"
      Meteor.subscribe "allUsers"


  #
  # Add New Expense Template
  #

  Template.addNewExpense.rendered = () ->
    Session.set('insertExpenseFormError', null)

  Template.addNewExpense.helpers
    'expenses': () -> Expenses
    'insertError': () -> Session.get('insertExpenseFormError')
    "files": () -> S3.collection.find()

  # Set AutoForm hooks:
  AutoForm.hooks
    insertExpenseForm:
      before:
        insert: (doc, template) ->  # set employeeId and managerId before inserting document into collection
          hook = this
          doc.employeeId = Meteor.user()._id
          doc.managerId = Meteor.user().profile.managerId
          doc.status = 'PendingApproval'

          files = $("input.file_bag")[0].files

          if files.length > 0
            S3.upload files, 'receipts', (err, result) ->
              if (err) 
                return hook.result(false)
              doc.receiptFileURL = result.secure_url
              hook.result(doc)
          else
            return doc
          
      after:
        insert: (error, result, template) ->
          console.log error, result

      onError: (operation, error, template) ->
        Session.set('insertExpenseFormError', error.message)

  #
  # showAccountantExpenses template
  #

  Template.showSuperAccountantExpenses.helpers
    'getExpenses': () ->
      return Expenses.find
        status: 
          $in: ['PendingApproval', 'PendingReimbursement']

    'expensesCollection': () -> Expenses
    
  Template.displayExpenseRow.helpers
    'currentExpense': () ->
      return Template.currentData()
    'isPendingApproval': () ->
      return Template.currentData().status == 'PendingApproval'
    'isPendingReimbursement': () ->
      return Template.currentData().status == 'PendingReimbursement'
    'getEmployee': () ->
      k = Meteor.users.findOne
        _id: Template.currentData().employeeId
      return k

  Template.displayExpenseRow.events =
    'click .approveExpenseButton': (e) ->
      expense = Template.currentData()
      # update record with new status
      Expenses.update
        _id: expense._id
      , $set:
        status: 'PendingReimbursement'

    'click .reimburseExpenseButton': (e) ->
      expense = Template.currentData()

      # TODO: pay expense

      console.log 'now we pay', expense

      #TODO: update record with new status
      # Expenses.update
      #   _id: expense._id
      # , $set:
      #   status: 'PendingReimbursement'


# Roles: employee, manager, accountant, superAccountant

# Accounts.createUser({
#   email: email,
#   password: password,
#   profile: {
#     name: 'John Doe',
#     dwollaId: '812-713-9234',
#     managerId: 'efefwef'
#   }  
# })