if Meteor.isClient
  # TODO: validate each potential expense object on the server side
  Meteor.subscribe "expensesCreatedByUser"
  
  # default session state:
  Session.set 'loginMessage', null

  # Iron Router routes...

  Router.route '/', () ->
    this.render('mainScreen')

  Router.route '/dwollaOAuthReturn', () ->
    this.render('OAuthReturn')

  # 
  # Helpers available to all templates
  #

  Template.registerHelper 'isSuperAccountant', () ->
    return Roles.userIsInRole Meteor.user()._id, 'superAccountant'

  Template.registerHelper 'isManager', () ->
    return Roles.userIsInRole Meteor.user()._id, 'manager'

  Template.registerHelper 'isAccountant', () ->
    return Roles.userIsInRole Meteor.user()._id, 'accountant'

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
    'ableToDelete': () ->
      return (_.contains(['PendingApproval', 'PendingReimbursement'], Template.currentData().status) )

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
  # showExpensesToApprove template
  #

  Template.showExpensesToApprove.helpers
    'getExpenses': () ->
      return Expenses.find
        status: 
          $in: ['PendingApproval']

    'expensesCollection': () -> Expenses

  #
  # showExpensesToReimburse template
  #

  Template.showExpensesToReimburse.helpers
    'getExpenses': () ->
      return Expenses.find
        status: 
          $in: ['PendingReimbursement']

    'expensesCollection': () -> Expenses
    'reimburseError': () -> Session.get('reimburseError')

  Template.showExpensesToReimburse.events =
    'click .reimburseCheckedExpensesButton': (e) ->
      expenses = $('.expenseToReimburseCheckbox:checked').map( (el) -> this.value ).get()
      pin = $('#PIN').val()

      Meteor.call 'reimburseCheckedExpenses', expenses, pin, (error, result) ->
        if error
          Session.set('reimburseError', error.reason)
        $.unblockUI();

      $.blockUI({message: 'Making it rain.  Hold your horses...'});

  #
  # displayExpenseRow template
  #
    
  Template.displayExpenseRow.helpers
    'currentExpense': () ->
      return Template.currentData()
    'ableToApprove': () ->
      return (Template.currentData().status == 'PendingApproval') && Roles.userIsInRole Meteor.user()._id, ['accountant', 'superAccountant', 'manager']
    'ableToReimburse': () ->
      return (Template.currentData().status == 'PendingReimbursement') && Roles.userIsInRole Meteor.user()._id, ['accountant', 'superAccountant']
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
        approvedByUserId: Meteor.user()._id

    'click .rejectExpenseButton': (e) ->
      expense = Template.currentData()
      # update record with new status
      Expenses.update
        _id: expense._id
      , $set:
        status: 'Rejected',
        rejectedByUserId: Meteor.user()._id

    'click .reimburseExpenseButton': (e) ->
      expense = Template.currentData()

      Meteor.call('reimburseExpense', expense)


# Roles: employee, manager, accountant, superAccountant

#
# Helper functions:
#

getQueryStringParam = (sVar) ->
  unescape(window.location.search.replace(new RegExp("^(?:.*[&\\?]" + escape(sVar).replace(/[\.\+\*]/g, "\\$&") + "(?:\\=([^&]*))?)?.*$", "i"), "$1"))