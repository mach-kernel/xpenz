@Payments = new Mongo.Collection 'payments'

Payments.attachSchema new SimpleSchema 
  employeeId:
    type: String
    optional: false
  expenseType:
    type: String
    optional: false
  total:
    type: String
    optional: false
  dwollaTransactionId:
    type: String
    optional: false
  createdDate:
    type: Date
    optional: false