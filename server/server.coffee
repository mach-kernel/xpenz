if Meteor.isServer
	#
	# define server methods
	#

	DWOLLA_OAUTH_REDIRECT_URL = 'http://127.0.0.1:3000/dwollaOAuthReturn'
	Dwolla = Meteor.npmRequire('dwolla-node')
	dwolla = Dwolla('JCGQXLrlfuOqdUYdTcLz3rBiCZQDRvdWIUPkw++GMuGhkem9Bo', 'g7QLwvO37aN2HoKx1amekWi8a2g7AIuPbD5C/JSLqXIcDOxfTr')
	dwolla.sandbox = true

	Future = Npm.require('fibers/future')

	Meteor.methods
		reimburseExpense: (expense) ->
			console.log 'trying to pay expense', expense

		OAuthGetURL: () ->
			dwolla.authUrl(DWOLLA_OAUTH_REDIRECT_URL)
			
		OAuthFinish: (code) ->
			if !code
				throw new Meteor.Error 'oauth-fail', 'Could not authorize account'

			dwolla.finishAuthSync = Meteor.wrapAsync dwolla.finishAuth
			dwolla.fullAccountInfoSync = Meteor.wrapAsync dwolla.fullAccountInfo

			auth = dwolla.finishAuthSync(code, DWOLLA_OAUTH_REDIRECT_URL)

			if auth && auth.error == 'access_denied'
				throw new Meteor.Error 'oauth-fail', 'Could not authorize account, could not get token'	
				
			dwolla.setToken(auth.access_token)
			accountInfo = dwolla.fullAccountInfoSync()	

			console.log 'Got account info'

			dwollaId = accountInfo.Id
			
			foundUser = Meteor.users.findOne({'profile.dwollaId': dwollaId})

			if foundUser
				# TODO: update the user's auth object with access token and refresh token
				this.setUserId(foundUser._id)

				console.log 'Logging user in'

				return { 
					resultCode: 'user-logged-in', 
					auth: auth,
					userId: foundUser._id
				}
			else
				return { 
					resultCode: 'create-new-user', 
					auth: auth,
					dwollaId: accountInfo.Id, 
					name: accountInfo.Name
				}
			
			return dwollaId

		registerUser: (email, dwollaId, name, managerId, auth) ->
			randomPassword = Math.random().toString(36).slice(2)
			userId = Accounts.createUser
				email: email,
				password: randomPassword, # TODO: don't rely on accounts-password for accounts...
				profile: 
				  name: name,
				  dwollaId: dwollaId,
				  managerId: managerId
				  auth: auth

			this.setUserId(userId)

			return userId


	#
	# publish records
	#

	Meteor.publish "expensesCreatedByUser", () ->
		Expenses.find({employeeId: this.userId})

	Meteor.publish "expensesWhichRequireManagerApproval", () ->
		Expenses.find({managerId: this.userId, status: 'pendingApproval'})

	Meteor.publish "expensesAllPendingApproval", () ->
		if Roles.userIsInRole this.userId, 'superAccountant'
			return Expenses.find({status: 'PendingApproval'})
		else
			# not allowed to get all expenses pending approval
			this.stop()
			return 

	Meteor.publish "expensesAllPendingReimbursement", () ->
		if Roles.userIsInRole this.userId, ['accountant', 'superAccountant']
			return Expenses.find({status: 'PendingReimbursement'})
		else
			# not allowed to get all pending reimbursements
			this.stop()
			return

	Meteor.publish "allUsers", () ->
		if Roles.userIsInRole this.userId, ['accountant', 'superAccountant', 'manager']
			# Manager, accountants and superAccountants can see all users, including their emails
			return Meteor.users.find()
		else
			this.stop()
			return

	S3.config = 

	Meteor.startup ->
		return