if Meteor.isClient
  # TODO: validate each potential expense object on the server side
  Meteor.subscribe "expensesCreatedByUser"
  
  # default session state:
  Session.set 'loginMessage', null

  # Define helper available to all methods:
  Template.registerHelper 'isSuperAccountant', () ->
    return Roles.userIsInRole Meteor.user()._id, 'superAccountant'

  # Iron Router routes...

  Router.route '/', () ->
    this.render('mainScreen')

  Router.route '/dwollaOAuthReturn', () ->
    this.render('OAuthReturn')

  #
  # Main Template
  #

  Template.mainScreen.helpers
    'needsToRegister': () -> Session.get('register')

  # 
  # OAuth Return iframe
  # 
  
  Template.OAuthReturn.rendered = () ->
    window.parent.postMessage('closeLightBox###' + getQueryStringParam('code'), '*')

  # handle message from iframe: close it and finish OAuth:
  window.addEventListener 'message', (e) -> 
    if (e.data.indexOf('closeLightBox') != -1)
      $.featherlight.current().close();

      authorizationCode = e.data.split('###')[1]

      Meteor.call 'OAuthFinish', authorizationCode, (error, result) ->
        Session.set('registerInfo', result)
        if result.resultCode == 'create-new-user'
          # if user doesn't exist, show register template
          Session.set('register', true)
        else if result.resultCode == 'user-logged-in'
          # if user exists, log the user in
          Session.set('register', false)
          Meteor.connection.setUserId(result.userId)
          
  #
  # Register Template
  #

  Template.register.helpers
    'name': () ->
      Session.get('registerInfo').name
    
  Template.register.events =
    'click button': (e) ->
      email = $('#email').val()
      managerId = $('#managerId').val()
      registerInfo = Session.get('registerInfo')
      name = registerInfo.name
      auth = registerInfo.auth
      dwollaId = registerInfo.dwollaId

      # create account, then bring to dashboard:
      Meteor.call('registerUser', email, dwollaId, name, managerId, auth, (error, newUserId) ->
        if newUserId
          Meteor.connection.setUserId(newUserId)
          Session.set('register', false)
        else
          # TODO; handle case when registration fails...
      )

  # 
  # Login template
  #

  Template.login.helpers
    'loginMessage': ->
        Session.get('loginMessage')

  Template.login.rendered = () ->
    Meteor.call('OAuthGetURL', (error, result) ->
      $('#loginClick').featherlight
        html: '<iframe id="loginIFrame" src="' + result + '" />'
    )

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

      Meteor.call('reimburseExpense', expense)

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

#
# Helper functions:
#

getQueryStringParam = (sVar) ->
  unescape(window.location.search.replace(new RegExp("^(?:.*[&\\?]" + escape(sVar).replace(/[\.\+\*]/g, "\\$&") + "(?:\\=([^&]*))?)?.*$", "i"), "$1"))