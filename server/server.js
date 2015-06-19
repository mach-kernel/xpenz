var DWOLLA_OAUTH_REDIRECT_URL, Dwolla, dwolla, mailType, processPayment, s3_linklife;

if (Meteor.isServer) {

    DWOLLA_OAUTH_REDIRECT_URL = process.env.ROOT_URL ? process.env.ROOT_URL + '/dwollaOAuthReturn' 
                                                     : 'http://localhost:3000/dwollaOAuthReturn';

    // Prepare Dwolla support
    Dwolla = Meteor.npmRequire('dwolla-node');
    dwolla = Dwolla(process.env.DWOLLA_KEY, process.env.DWOLLA_SECRET);
    dwolla.sandbox = true;

    // Async-wrap sync calls to dwolla-node
    dwolla.finishAuthSync = Meteor.wrapAsync(dwolla.finishAuth);
    dwolla.fullAccountInfoSync = Meteor.wrapAsync(dwolla.fullAccountInfo);
    dwolla.sendSync = Meteor.wrapAsync(dwolla.send);
    dwolla.fsSync = Meteor.wrapAsync(dwolla.fundingSources);


    // AWS/S3 Configuration
    S3.config = {
        key: process.env.XPENZ_S3_KEY,
        secret: process.env.XPENZ_S3_SECRET,
        bucket: process.env.XPENZ_S3_BUCKET
    };

    s3_linklife = process.env.XPENZ_S3_LINKLIFE ? process.env.XPENZ_S3_LINKLIFE : 15;

    // Quick and dirty "enum"
    mailType = {
        APPROVED: 0,
        REJECTED: 1,
        REIMBURSED: 2
    };


    Meteor.methods({
        reimburseCheckedExpenses: function(expenseIds, pin) {
            var employeesToExpenses, employeesToExpensesByType, expenses, payments;
            if (!Roles.userIsInRole(this.userId, ['accountant', 'superAccountant'])) {
                throw new Meteor.Error('reimburse-fail', 'User is not allowed to reimburse expenses');
            }
            expenses = Expenses.find({
                _id: {
                    $in: expenseIds
                },
                status: 'PendingReimbursement'
            }).fetch();
            payments = [];
            employeesToExpenses = _.groupBy(expenses, function(expense) {
                return expense.employeeId;
            });
            employeesToExpensesByType = _.each(_.keys(employeesToExpenses), function(employeeId) {
                var expensesByType;
                expensesByType = _.groupBy(employeesToExpenses[employeeId], function(expense) {
                    return expense.type;
                });
                return _.each(_.keys(expensesByType), function(type) {
                    return payments.push({
                        employeeId: employeeId,
                        expenseType: type,
                        expenseDate: date,
                        expenseTrip: trip,
                        expenses: expensesByType[type]
                    });
                });
            });
            console.log(payments);
            payments.forEach(function(payment) {
                return processPayment(payment, Meteor.user(), pin);
            });
            return true;
        },
        OAuthGetURL: function() {
            return dwolla.authUrl(DWOLLA_OAUTH_REDIRECT_URL);
        },
        OAuthFinish: function(code) {
            var accountInfo, auth, foundUser;
            if (!code) {
                throw new Meteor.Error('oauth-fail', 'Could not authorize account');
            }
            auth = dwolla.finishAuthSync(code, DWOLLA_OAUTH_REDIRECT_URL);
            if (auth && auth.error === 'access_denied') {
                throw new Meteor.Error('oauth-fail', 'Could not authorize account, could not get token');
            }
            dwolla.setToken(auth.access_token);
            accountInfo = dwolla.fullAccountInfoSync();
            foundUser = Meteor.users.findOne({
                'profile.dwollaId': accountInfo.Id
            });
            if (foundUser) {
                Meteor.users.update({
                    _id: foundUser._id
                }, {
                    $set: {
                        'profile.auth': auth
                    }
                });
                this.setUserId(foundUser._id);
                return {
                    resultCode: 'user-logged-in',
                    auth: auth,
                    userId: foundUser._id
                };
            } else {
                return {
                    resultCode: 'create-new-user',
                    auth: auth,
                    dwollaId: accountInfo.Id,
                    name: accountInfo.Name
                };
            }
            return dwollaId;
        },
        registerUser: function(email, dwollaId, name, managerId, auth) {
            var randomPassword, userId;
            randomPassword = Math.random().toString(36).slice(2);
            userId = Accounts.createUser({
                email: email,
                password: randomPassword,
                profile: {
                    name: name,
                    dwollaId: dwollaId,
                    managerId: managerId,
                    auth: auth,
                    fundingSource: "Balance"
                }
            });
            this.setUserId(userId);
            return userId;
        },
        getFS: function(fundingUser) {
            dwolla.setToken(fundingUser.profile.auth.access_token);
            return dwolla.fsSync();
        },
        sendMail: function(userId, type, action, amount) {
            var dest, kw, news, subj;
            if (amount == null) {
                amount = false;
            }
            dest = Meteor.users.findOne({
                _id: userId
            });
            kw = '';
            news = '';
            switch (action) {
                case mailType.APPROVED:
                    kw = 'approved';
                    news = 'approved by your manager and is pending reimbursement!';
                    break;
                case mailType.REJECTED:
                    kw = 'rejected';
                    news = 'rejected by your manager. Sorry!';
                    break;
                case mailType.REIMBURSED:
                    kw = 'reimbursed';
                    news = 'reimbursed in the amount of $' + amount + ' and should now be available in your Dwolla balance!';
                    break;
                default:
                    return;
            }
            subj = 'xpenz: Your expense has been ' + kw + '.';
            Email.send({
                from: "xpenz@dwolla.com",
                to: dest.emails[0]['address'],
                subject: subj,
                text: 'Hello ' + dest.profile.name + '!\n' + 'An expense you submitted for ' + type + ' has been ' + news
            });
            return Email.send({
                from: "xpenz@dwolla.com",
                to: "accounting@dwolla.com",
                subject: "[COPY] " + subj,
                text: 'An expense submitted by ' + dest.profile.name + ' for ' + type(' has been ' + news)
            });
        },
        inviteMail: function(email, managerId) {
            var mgr;
            mgr = Meteor.users.findOne({
                _id: managerId
            });
            return Email.send({
                from: 'xpenz@dwolla.com',
                to: email,
                subject: 'You\'ve been invited to xpenz!',
                text: 'Hi there!\nYou have been invited by ' + mgr.profile.name + ' to xpenz, a system ' + 'for tracking company expenses!\n\nClick this link in order to complete registration ' + 'and have your Dwolla account information handy: ' + process.env.ROOT_URL + '?invite=' + mgr._id
            });
        },
        getSecureURL: function(filename) {
            var expires;
            expires = new Date();
            expires.setMinutes(expires.getMinutes() + s3_linklife);
            return {
                url: S3.knox.signedUrl(String(filename), expires, {
                    expiry: expires
                })
            };
        }
    }, processPayment = function(payment, sendingUser, pin) {
        var destinationId, e, employeeToBeReimbursed, expenseIds, paymentId, token, totalAmount, txid;
        token = sendingUser.profile.auth.access_token;
        dwolla.setToken(token) * (employeeToBeReimbursed = Meteor.users.findOne({
            _id: payment.employeeId
        }));
        destinationId = employeeToBeReimbursed.profile.dwollaId;
        totalAmount = payment.expenses.map(function(expense) {
            return parseFloat(expense.amount);
        }).reduce(function(n, r) {
            return n + r;
        });
        try {
            txid = dwolla.sendSync(pin, destinationId, totalAmount, {
                notes: 'Expense: ' + payment.expenseDate + ' ' + payment.expenseType + ' ' + payment.expenseTrip,
                fundsSource: sendingUser.profile.fundingSource,
                assumeCosts: true
            });
        } catch (_error) {
            e = _error;
            throw new Meteor.Error('payment-fail', 'Could not send Dwolla payment: ' + e.message);
        }
        if (!txid) {
            throw new Meteor.Error('payment-fail', 'Could not send Dwolla payment');
        }
        paymentId = Payments.insert({
            employeeId: employeeToBeReimbursed._id,
            expenseType: payment.expenseType,
            total: totalAmount,
            dwollaTransactionId: txid,
            createdDate: new Date()
        });
        expenseIds = payment.expenses.map(function(e) {
            return e._id;
        });
        Expenses.update({
            _id: {
                $in: expenseIds
            }
        }, {
            $set: {
                paymentId: paymentId,
                status: 'Reimbursed',
                reimbursedByUserId: sendingUser._id
            }
        }, {
            multi: true
        });
        sendMail(payment.employeeId, payment.expenseType, 2, totalAmount);
        return paymentId;
    });
    Meteor.publish("expensesCreatedByUser", function() {
        return Expenses.find({
            employeeId: this.userId
        }, {sort: {type: 1}, responsive: false});
    });
    Meteor.publish("expensesWhichRequireManagerApproval", function() {
        return Expenses.find({
            managerId: this.userId,
            status: 'PendingApproval'
        }, {sort: {type: 1}, responsive: false});
    });
    Meteor.publish("expensesAllPendingApproval", function() {
        if (Roles.userIsInRole(this.userId, 'superAccountant')) {
            return Expenses.find({
                status: 'PendingApproval'
            }, {sort: {type: 1}, responsive: false});
        } else {
            this.stop();
        }
    });
    Meteor.publish("expensesAllPendingReimbursement", function() {
        if (Roles.userIsInRole(this.userId, ['accountant', 'superAccountant'])) {
            return Expenses.find({
                status: 'PendingReimbursement'
            }, {sort: {type: 1}, responsive: false});
        } else {
            this.stop();
        }
    });
    Meteor.publish("allUsers", function() {
        if (Roles.userIsInRole(this.userId, ['accountant', 'superAccountant', 'manager'])) {
            return Meteor.users.find();
        } else {
            this.stop();
        }
    });
    Meteor.startup(function() {
        Roles.addUsersToRoles('PhiB83x9N9XWGuBHG', 'superAccountant');
        Roles.addUsersToRoles('2xi3fty4oFZWoNh6S', 'superAccountant');
        Roles.addUsersToRoles('SkDxPuy57oRyF8dmS', 'superAccountant');
    });
}