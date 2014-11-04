if Meteor.isServer
	Expenses = new Mongo.Collection 'expenses'

	Meteor.startup ->
		return