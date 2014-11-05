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
    receiptFileURL:
      type: String
      optional: true

  # TODO: validate each potential expense object on the server side
  Meteor.subscribe "expensesCreatedByUser"
  

  # TODO: if user is manager, subscribe them to:
  # Meteor.subscribe "expensesWhichRequireManagerApproval"

  # TODO: if user is accountant, subscribe them to:
  # Meteor.subscribe "expensesAllPendingApproval"
  # Meteor.subscribe "expensesAllPendingReimbursement"

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
          S3.upload files, 'receipts', (err, result) ->
            console.log result
            doc.receiptFileURL = result.secure_url
            hook.result(doc)
          
          console.log doc
          

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

  Template.showExpenses.rendered = () ->
    $('.receipt')


  #
  # Add New Expense Template
  #

  Template.addNewExpense.rendered = () ->
    Session.set('insertExpenseFormError', null)

  Template.addNewExpense.helpers
    'expenses': () -> Expenses
    'insertError': () -> Session.get('insertExpenseFormError')
    "files": () -> S3.collection.find()

  # Template.addNewExpense.events =
  #   'keypress': (e) ->
  #     if e.keyCode == 13
  #       $('#createExpenseButton').submit()


    #Object {percent_uploaded: 100, uploading: false, url: "http://dlabshr.s3.amazonaws.com/receipts/zCr5YAGtuq9MdBCHS.png", secure_url: "https://dlabshr.s3.amazonaws.com/receipts/zCr5YAGtuq9MdBCHS.png", relative_url: "receipts/zCr5YAGtuq9MdBCHS.png"}
    

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