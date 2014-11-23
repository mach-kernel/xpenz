if Meteor.isServer
	# 
	# Constants
	#

	DWOLLA_OAUTH_REDIRECT_URL = 'http://127.0.0.1:3000/dwollaOAuthReturn'

	# Set up Dwolla API bindings
	Dwolla = Meteor.npmRequire('dwolla-node')
	dwolla = Dwolla('JCGQXLrlfuOqdUYdTcLz3rBiCZQDRvdWIUPkw++GMuGhkem9Bo', 'g7QLwvO37aN2HoKx1amekWi8a2g7AIuPbD5C/JSLqXIcDOxfTr')
	dwolla.sandbox = true

	# wrap the async dwolla methods so that they are synchronous
	dwolla.finishAuthSync = Meteor.wrapAsync dwolla.finishAuth
	dwolla.fullAccountInfoSync = Meteor.wrapAsync dwolla.fullAccountInfo
	dwolla.sendSync = Meteor.wrapAsync dwolla.send

	# Future = Npm.require('fibers/future')

	#
	# define server methods
	#

	Meteor.methods
		reimburseExpense: (expense) ->
			token = Meteor.user().profile.auth.access_token
			dwolla.setToken(token)
			employeeToBeReimbursed = Meteor.users.findOne({_id: expense.employeeId})
			destinationId = employeeToBeReimbursed.profile.dwollaId
			console.log 'trying to pay expense', expense, token, destinationId

			txid = dwolla.sendSync(9999, destinationId, expense.amount, {
				notes: 'Expense ID:' + expense._id,
				assumeCosts: true
			})

			if !txid
				throw new Meteor.Error 'reimburse-fail', 'Could not send Dwolla payment'

			# update Expense with transaction id and new status
			Expenses.update {_id: expense._id}, 
				$set:
					paidTransactionId: txid
					status: 'Reimbursed'

			console.log txid

			return txid

		OAuthGetURL: () ->
			dwolla.authUrl(DWOLLA_OAUTH_REDIRECT_URL)

		OAuthFinish: (code) ->
			if !code
				throw new Meteor.Error 'oauth-fail', 'Could not authorize account'

			# try to fetch access token
			auth = dwolla.finishAuthSync(code, DWOLLA_OAUTH_REDIRECT_URL)

			if auth && auth.error == 'access_denied'
				throw new Meteor.Error 'oauth-fail', 'Could not authorize account, could not get token'	
				
			# Call the Dwolla Account Info API to get the user's Dwolla ID, and see if a user with that ID already has an account
			dwolla.setToken(auth.access_token)
			accountInfo = dwolla.fullAccountInfoSync()	
			foundUser = Meteor.users.findOne({'profile.dwollaId': accountInfo.Id})

			if foundUser
				# TODO: update the user's auth object with access token and refresh token
				this.setUserId(foundUser._id)
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