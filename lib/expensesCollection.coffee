@Expenses = new Mongo.Collection 'expenses'

Expenses.attachSchema new SimpleSchema
  status:
    type: String
    optional: false
    allowedValues: ['PendingApproval', 'PendingReimbursement', 'Rejected', 'Reimbursed']
  type:
    type: String
    optional: false
    allowedValues: ['Ground Transport', 'Office Supplies', 'Flights', 'Lodging', 'Food', 'Other']
    label: 'Type'
  vendor: 
    type: String
    label: 'Who was paid?'
    optional: false
    max: 200
  description:
    type: String
    optional: false
    label: 'Description'
    max: 500
  trip:
    type: String
    optional: true
    label: 'Trip'
    max: 500
  amount: # TODO: consider using cents to store amount
    type: String
    optional: false
    label: 'Amount'
  date:
    type: Date
    optional: false
    label: 'Date Incurred'
  receiptFileURL:
    type: String
    optional: true

  # Users involved with this expense:

  employeeId:
    optional: false
    type: String
  managerId:
    optional: false
    type: String
  approvedByUserId:
    type: String
    optional: true
  reimbursedByUserId:
    type: String
    optional: true
  rejectedByUserId:
    type: String
    optional: true
  paymentId:
    optional: true
    type: String
    