if Meteor.isClient
  # TODO: validate each potential expense object on the server side
  Meteor.subscribe "expensesCreatedByUser"
  Meteor.subscribe "allUsers"
  
  # default session state:
  Session.set 'loginMessage', null
  Session.set 'showAdminSettings', false

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

  Template.registerHelper 'formatDate', (date) ->
    return date.toLocaleDateString()

  Template.registerHelper 'formatAmount', (amount) ->
    return parseFloat(amount).toFixed(2)

  Template.registerHelper 'userSchema', () ->
    return userSchema

  Template.registerHelper 'generateEditUserFormId', () ->
    return 'editUserForm-' + Template.currentData()._id

  Template.registerHelper 'getManagerOptions', () ->
    managers = Roles.getUsersInRole('manager').fetch()
    return managers.map (manager) ->
      return {label: manager.profile.name, value: manager._id}

  Template.registerHelper 'getFundingSources', () ->
    Meteor.call 'getFS', Meteor.user(), (error, data) ->
      Session.set("FS-" + Meteor.user()._id, data)
    return Session.get("FS-"+ Meteor.user()._id).map (fundingsource) ->
      return {label: fundingsource.Name, value: fundingsource.Id}  
      

  #
  # Main Template
  #

  Template.mainScreen.events =
    'click #adminSettingsShowButton': () ->
      Session.set('showAdminSettings', true)
    'click #adminSettingsHideButton': () ->
      Session.set('showAdminSettings', false)

  Template.mainScreen.helpers
    'needsToRegister': () -> Session.get('register')
    'showAdminSettings': () -> Session.get('showAdminSettings')
    'isInvited': () -> Session.get('invite')

  #
  # adminSettings template
  #

  Template.adminSettings.helpers
    'users': () -> Meteor.users.find()
    'getManager': () ->
      managerId = Template.currentData().profile.managerId
      return Meteor.users.findOne({_id: managerId})
    'role': () ->
      user = Template.currentData()
      return Roles.getRolesForUser user
    'isUsersManager': () ->
      return true

  Template.adminSettings.events
    'click #invite': (e) ->
      dest = $('#email').val()
      Meteor.call('inviteMail', dest, Meteor.user()._id)
      alert 'Invite sent to ' + dest + '!'
      $('#email').val('')

  # 
  # OAuth Return iframe
  # 

  Template.OAuthReturn.rendered = () ->
    authorizationCode = getQueryStringParam('code')
    console.log(authorizationCode)
    Meteor.call 'OAuthFinish', authorizationCode, (error, result) ->
      Session.set('registerInfo', result)
      if result.resultCode == 'create-new-user'
        # if user doesn't exist, show register template
        # if there is a 'invite' code, send them to the invite template instead
        if getQueryStringParam('invite').length
          Session.set('register', false)
          Session.set('invite', true)
        else
          Session.set('register', true)
      else if result.resultCode == 'user-logged-in'
        # if user exists, log the user in
        Session.set('register', false)
        Meteor.connection.setUserId(result.userId)
        UI.insert(UI.render(Template.mainScreen), document.body)
          
  #
  # Register Templates
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

  Template.invite.helpers
    'name': () ->
        Session.get('registerInfo').name
        
  Template.invite.events =
    'click button': (e) ->
      email = $('#email').val()
      managerId = getQueryStringParam('invite')
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
      $('#loginClick').on "click", ->
        window.location.replace(result)
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
      expenses = Expenses.find
        employeeId: Meteor.user()._id

      expenses.forEach (expense) ->
        if !expense.secureURLexpiry || expense.secureURLexpiry < Date.now()       
          Meteor.call 'getSecureURL', expense.receiptFileURL, (error, data) ->
            Expenses.update({_id: expense._id}, {$set:{secureURL: data.url}})
            Expenses.update({_id: expense._id}, {$set:{secureURLexpiry: data.expiry}})
      return expenses

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

          Session.set 'lastSubmittedExpense', doc

          files = $("input.file_bag")[0].files


          if files.length > 0
            S3.upload files, 'receipts', (err, result) ->
              if (err) 
                return hook.result(false)

              doc.receiptFileURL = result.relative_url
              hook.result(doc)
          else
            return doc
          
      after:
        insert: (error, result, template) ->
          expense = Session.get 'lastSubmittedExpense'
          $('input[name="type"]').val(expense.type)
          $('input[name="trip"]').val(expense.trip)
          $('input[name="vendor"]').val(expense.vendor)
          $('input[name="date"]').val expense.date.toISOString().split('T')[0]
          this.autorun

      onError: (operation, error, template) ->
        Session.set('insertExpenseFormError', error.message)

  # File input field, show file name when selected
  $(document).on 'change', '.btn-file :file', () ->
    input = $(this)
    label = input.val().replace(/\\/g, '/').replace(/.*\//, '')
    
    fileInputField = $(this).parents('.input-group').find(':text')
    fileInputField.val(label)

  #
  # showExpensesToApprove template
  #

  Template.showExpensesToApprove.helpers
    'getExpenses': () ->
      expenses = Expenses.find
        status: 
          $in: ['PendingApproval']

      expenses.forEach (expense) ->
        if !expense.secureURLexpiry || expense.secureURLexpiry < Date.now()       
          Meteor.call 'getSecureURL', expense.receiptFileURL, (error, data) ->
            Expenses.update({_id: expense._id}, {$set:{secureURL: data.url}})
            Expenses.update({_id: expense._id}, {$set:{secureURLexpiry: data.expiry}})
      return expenses

    'expensesCollection': () -> Expenses

  #
  # showExpensesToReimburse template
  #

  Template.showExpensesToReimburse.helpers
    'getExpenses': () ->
      expenses = Expenses.find
        status: 
          $in: ['PendingReimbursement']

      expenses.forEach (expense) ->
        if !expense.secureURLexpiry || expense.secureURLexpiry < Date.now()       
          Meteor.call 'getSecureURL', expense.receiptFileURL, (error, data) ->
            Expenses.update({_id: expense._id}, {$set:{secureURL: data.url}})
            Expenses.update({_id: expense._id}, {$set:{secureURLexpiry: data.expiry}})
      return expenses

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
      Meteor.call('sendMail', expense.employeeId, expense.type, 0)

    'click .rejectExpenseButton': (e) ->
      expense = Template.currentData()
      # update record with new status
      Expenses.update
        _id: expense._id
      , $set:
        status: 'Rejected',
        rejectedByUserId: Meteor.user()._id
      Meteor.call('sendMail', expense.employeeId, expense.type, 1)

    'click .reimburseExpenseButton': (e) ->
      expense = Template.currentData()
      Meteor.call('reimburseExpense', expense)


# Roles: employee, manager, accountant, superAccountant

#
# Helper functions:
#

getQueryStringParam = (sVar) ->
  unescape(window.location.search.replace(new RegExp("^(?:.*[&\\?]" + escape(sVar).replace(/[\.\+\*]/g, "\\$&") + "(?:\\=([^&]*))?)?.*$", "i"), "$1"))
