if Meteor.isServer
	Expenses = Mongo.Collection('expenses')

	Meteor.startup ->
		return