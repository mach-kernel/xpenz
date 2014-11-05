if Meteor.isServer
	Expenses = new Mongo.Collection 'expenses'

	#publish records:

	Meteor.publish "expensesCreatedByUser", () ->
		Expenses.find({employeeId: this.userId})

	Meteor.publish "expensesWhichRequireManagerApproval", () ->
		Expenses.find({managerId: this.userId, status: 'pendingApproval'})

	Meteor.publish "expensesAllPendingApproval", () ->
		Expenses.find({status: 'pendingApproval'})

	Meteor.publish "expensesAllPendingReimbursement", () ->
		Expenses.find({status: 'pendingReimbursement'})

	S3.config = 
    key: '',
    secret: '',
    bucket: ''

	Meteor.startup ->
		return