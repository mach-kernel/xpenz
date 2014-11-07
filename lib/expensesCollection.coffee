# declare collections:
@Expenses = new Mongo.Collection 'expenses'

Expenses.attachSchema new SimpleSchema
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
    type:
      type: String
      optional: false
      allowedValues: ['Ground Transportation', 'Office Supplies', 'Flights', 'Lodging', 'Food', 'Other']
      label: 'Type'
    date:
      type: Date
      optional: false
      label: 'Date Incurred'
    employeeId:
      optional: false
      type: String
    managerId:
      optional: false
      type: String
    paidTransactionId:
      optional: true
      type: String
    status:
      type: String
      optional: false
      allowedValues: ['PendingApproval', 'PendingReimbursement', 'Rejected', 'Reimbursed']
    receiptFileURL:
      type: String
      optional: true