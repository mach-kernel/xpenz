if Meteor.isServer
	#publish records:
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

    key: '',
    secret: '',
    bucket: ''
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