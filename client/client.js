var getQueryStringParam;

if (Meteor.isClient) {
    Meteor.subscribe("expensesCreatedByUser");
    Meteor.subscribe("allUsers");
    Session.set('loginMessage', null);
    Session.set('showAdminSettings', false);
    Router.route('/', function() {
        return this.render('mainScreen');
    });
    Router.route('/dwollaOAuthReturn', function() {
        return this.render('OAuthReturn');
    });
    Template.registerHelper('isSuperAccountant', function() {
        return Roles.userIsInRole(Meteor.user()._id, 'superAccountant');
    });
    Template.registerHelper('isManager', function() {
        return Roles.userIsInRole(Meteor.user()._id, 'manager');
    });
    Template.registerHelper('isAccountant', function() {
        return Roles.userIsInRole(Meteor.user()._id, 'accountant');
    });
    Template.registerHelper('formatDate', function(date) {
        return date.toLocaleDateString();
    });
    Template.registerHelper('formatAmount', function(amount) {
        return parseFloat(amount).toFixed(2);
    });
    Template.registerHelper('userSchema', function() {
        return userSchema;
    });
    Template.registerHelper('generateEditUserFormId', function() {
        return 'editUserForm-' + Template.currentData()._id;
    });
    Template.registerHelper('getManagerOptions', function() {
        var managers;
        managers = Roles.getUsersInRole('manager').fetch();
        return managers.map(function(manager) {
            return {
                label: manager.profile.name,
                value: manager._id
            };
        });
    });
    Template.registerHelper('getFundingSources', function() {
        Meteor.call('getFS', Meteor.user(), function(error, data) {
            return Session.set("FS-" + Meteor.user()._id, data);
        });
        return Session.get("FS-" + Meteor.user()._id).map(function(fundingsource) {
            return {
                label: fundingsource.Name,
                value: fundingsource.Id
            };
        });
    });
    Template.mainScreen.events = {
        'click #adminSettingsShowButton': function() {
            return Session.set('showAdminSettings', true);
        },
        'click #adminSettingsHideButton': function() {
            return Session.set('showAdminSettings', false);
        },
        'click #hideUserHist': function() {
            Session.set('showUserHistory', false);
            return Session.set('userHistoryId', false);
        }
    };
    Template.mainScreen.helpers({
        'needsToRegister': function() {
            return Session.get('register');
        },
        'showAdminSettings': function() {
            return Session.get('showAdminSettings');
        },
        'isInvited': function() {
            return Session.get('invite');
        },
        'showUserHistory': function() {
            return Session.get('showUserHistory');
        }
    });
    Template.adminSettings.helpers({
        'users': function() {
            return Meteor.users.find();
        },
        'getManager': function() {
            var managerId;
            managerId = Template.currentData().profile.managerId;
            return Meteor.users.findOne({
                _id: managerId
            });
        },
        'role': function() {
            var user;
            user = Template.currentData();
            return Roles.getRolesForUser(user);
        },
        'isUsersManager': function() {
            return true;
        },
        'showUserHistory': function() {
            return Session.get('showUserHistory');
        }
    });
    Template.adminSettings.events({
        'click #invite': function(e) {
            var dest;
            dest = $('#email').val();
            Meteor.call('inviteMail', dest, Meteor.user()._id);
            alert('Invite sent to ' + dest + '!');
            return $('#email').val('');
        },
        'click #viewUserHist': function(event) {
            Session.set('showUserHistory', true);
            Session.set('userHistoryId', event.target.form.id.split('-', 2)[1]);
            console.log("toggle on");
            return console.log(event.target.form.id.split('-', 2)[1]);
        }
    });
    Template.userHistory.helpers({
        'getRejectedExpensesById': function() {
            var rej;
            rej = Expenses.find({
                employeeId: Session.get('userHistoryId'),
                status: 'Rejected'
            });
            rej.forEach(function(expense) {
                if (expense.receiptFileURL && (!expense.secureURLexpiry || expense.secureURLexpiry < Date.now())) {
                    return Meteor.call('getSecureURL', expense.receiptFileURL, function(error, data) {
                        Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURL: data.url
                            }
                        });
                        return Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURLexpiry: data.expiry
                            }
                        });
                    });
                }
            });
            return rej;
        },
        'getReimbursedExpensesById': function() {
            var reimb;
            reimb = Expenses.find({
                employeeId: Session.get('userHistoryId'),
                status: 'Reimbursed'
            });
            reimb.forEach(function(expense) {
                if (expense.receiptFileURL && (!expense.secureURLexpiry || expense.secureURLexpiry < Date.now())) {
                    return Meteor.call('getSecureURL', expense.receiptFileURL, function(error, data) {
                        Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURL: data.url
                            }
                        });
                        return Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURLexpiry: data.expiry
                            }
                        });
                    });
                }
            });
            return reimb;
        },
        'getEmployee': function() {
            var k;
            k = Meteor.users.findOne({
                _id: Session.get('userHistoryId')
            });
            return k;
        }
    });
    Template.OAuthReturn.rendered = function() {
        var authorizationCode;
        authorizationCode = getQueryStringParam('code');
        return Meteor.call('OAuthFinish', authorizationCode, function(error, result) {
            Session.set('registerInfo', result);
            if (result.resultCode === 'create-new-user') {
                if (getQueryStringParam('invite').length) {
                    Session.set('register', false);
                    Session.set('invite', true);
                    UI.insert(UI.render(Template.invite), document.body);
                    return history.pushState('/', 'xpenz', '/invite');
                } else {
                    Session.set('register', true);
                    UI.insert(UI.render(Template.register), document.body);
                    return history.pushState('/', 'xpenz', '/register');
                }
            } else if (result.resultCode === 'user-logged-in') {
                Session.set('register', false);
                Meteor.connection.setUserId(result.userId);
                document.body.innerHTML = '';
                UI.insert(UI.render(Template.mainScreen), document.body);
                return history.pushState('/', 'xpenz', '/');
            }
        });
    };
    Template.register.helpers({
        'name': function() {
            return Session.get('registerInfo').name;
        }
    });
    Template.register.events = {
        'click button': function(e) {
            var auth, dwollaId, email, managerId, name, registerInfo;
            email = $('#email').val();
            managerId = $('#managerId').val();
            registerInfo = Session.get('registerInfo');
            name = registerInfo.name;
            auth = registerInfo.auth;
            dwollaId = registerInfo.dwollaId;
            return Meteor.call('registerUser', email, dwollaId, name, managerId, auth, function(error, newUserId) {
                if (newUserId) {
                    Meteor.connection.setUserId(newUserId);
                    Session.set('register', false);
                    document.body.innerHTML = '';
                    UI.insert(UI.render(Template.mainScreen), document.body);
                    return history.pushState('/', 'xpenz', '/');
                } else {

                }
            });
        }
    };
    Template.invite.helpers({
        'name': function() {
            return Session.get('registerInfo').name;
        }
    });
    Template.invite.events = {
        'click button': function(e) {
            var auth, dwollaId, email, managerId, name, registerInfo;
            email = $('#email').val();
            managerId = getQueryStringParam('invite');
            registerInfo = Session.get('registerInfo');
            name = registerInfo.name;
            auth = registerInfo.auth;
            dwollaId = registerInfo.dwollaId;
            return Meteor.call('registerUser', email, dwollaId, name, managerId, auth, function(error, newUserId) {
                if (newUserId) {
                    Meteor.connection.setUserId(newUserId);
                    Session.set('invite', false);
                    document.body.innerHTML = '';
                    UI.insert(UI.render(Template.mainScreen), document.body);
                    return history.pushState('/', 'xpenz', '/');
                } else {

                }
            });
        }
    };
    Template.login.helpers({
        'loginMessage': function() {
            return Session.get('loginMessage');
        }
    });
    Template.login.rendered = function() {
        return Meteor.call('OAuthGetURL', function(error, result) {
            return $('#loginClick').on("click", function() {
                return window.location.replace(result);
            });
        });
    };
    Template.login.events = {
        'click button, keydown': function(e) {
            var email, password;
            if (e.type === 'keydown' && e.which !== 13) {
                return;
            }
            email = $('#email').val();
            password = $('#password').val();
            return Meteor.loginWithPassword(email, password, function(error) {
                if (error) {
                    return Session.set('loginMessage', error.reason);
                } else {
                    return Session.set('loginMessage', 'Welcome' + Meteor.user().profile.name);
                }
            });
        }
    };
    Template.welcome.events = {
        'click #logoutButton': function() {
            return Meteor.logout();
        }
    };
    Template.showUserExpenses.helpers({
        'getExpenses': function() {
            var expenses;
            expenses = Expenses.find({
                employeeId: Meteor.user()._id
            });
            expenses.forEach(function(expense) {
                if (expense.receiptFileURL && (!expense.secureURLexpiry || expense.secureURLexpiry < Date.now())) {
                    return Meteor.call('getSecureURL', expense.receiptFileURL, function(error, data) {
                        Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURL: data.url
                            }
                        });
                        return Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURLexpiry: data.expiry
                            }
                        });
                    });
                }
            });
            return expenses;
        },
        'expensesCollection': function() {
            return Expenses;
        },
        'ableToDelete': function() {
            return _.contains(['PendingApproval', 'PendingReimbursement'], Template.currentData().status);
        }
    });
    Template.showUserExpenses.rendered = function() {
        if (Roles.userIsInRole(Meteor.user()._id, 'superAccountant')) {
            Meteor.subscribe("expensesAllPendingApproval");
            Meteor.subscribe("expensesAllPendingReimbursement");
            Meteor.subscribe("allUsers");
        }
        if (Roles.userIsInRole(Meteor.user()._id, 'accountant')) {
            Meteor.subscribe("expensesAllPendingReimbursement");
            Meteor.subscribe("allUsers");
        }
        if (Roles.userIsInRole(Meteor.user()._id, 'manager')) {
            Meteor.subscribe("expensesWhichRequireManagerApproval");
            return Meteor.subscribe("allUsers");
        }
    };
    Template.addNewExpense.rendered = function() {
        return Session.set('insertExpenseFormError', null);
    };
    Template.addNewExpense.helpers({
        'expenses': function() {
            return Expenses;
        },
        'insertError': function() {
            return Session.get('insertExpenseFormError');
        },
        "files": function() {
            return S3.collection.find();
        }
    });
    AutoForm.hooks({
        insertExpenseForm: {
            before: {
                insert: function(doc, template) {
                    var files, hook;
                    hook = this;
                    doc.employeeId = Meteor.user()._id;
                    doc.managerId = Meteor.user().profile.managerId;
                    doc.status = 'PendingApproval';
                    Session.set('lastSubmittedExpense', doc);
                    files = $("input.file_bag")[0].files;
                    if (files.length > 0) {
                        return S3.upload(files, 'receipts', function(err, result) {
                            if (err) {
                                return hook.result(false);
                            }
                            doc.receiptFileURL = result.relative_url;
                            return hook.result(doc);
                        });
                    } else {
                        return doc;
                    }
                }
            },
            after: {
                insert: function(error, result, template) {
                    var expense;
                    expense = Session.get('lastSubmittedExpense');
                    $('input[name="type"]').val(expense.type);
                    $('input[name="trip"]').val(expense.trip);
                    $('input[name="vendor"]').val(expense.vendor);
                    $('input[name="date"]').val(expense.date.toISOString().split('T')[0]);
                    return this.autorun;
                }
            },
            onError: function(operation, error, template) {
                return Session.set('insertExpenseFormError', error.message);
            }
        }
    });
    $(document).on('change', '.btn-file :file', function() {
        var fileInputField, input, label;
        input = $(this);
        label = input.val().replace(/\\/g, '/').replace(/.*\//, '');
        fileInputField = $(this).parents('.input-group').find(':text');
        return fileInputField.val(label);
    });
    Template.showExpensesToApprove.helpers({
        'getExpenses': function() {
            var expenses;
            expenses = Expenses.find({
                status: {
                    $in: ['PendingApproval']
                }
            });
            expenses.forEach(function(expense) {
                if (expense.receiptFileURL && (!expense.secureURLexpiry || expense.secureURLexpiry < Date.now())) {
                    return Meteor.call('getSecureURL', expense.receiptFileURL, function(error, data) {
                        Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURL: data.url
                            }
                        });
                        return Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURLexpiry: data.expiry
                            }
                        });
                    });
                }
            });
            return expenses;
        },
        'expensesCollection': function() {
            return Expenses;
        }
    });
    Template.showExpensesToReimburse.helpers({
        'getExpenses': function() {
            var expenses;
            expenses = Expenses.find({
                status: {
                    $in: ['PendingReimbursement']
                }
            });
            expenses.forEach(function(expense) {
                if (expense.receiptFileURL && (!expense.secureURLexpiry || expense.secureURLexpiry < Date.now())) {
                    return Meteor.call('getSecureURL', expense.receiptFileURL, function(error, data) {
                        Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURL: data.url
                            }
                        });
                        return Expenses.update({
                            _id: expense._id
                        }, {
                            $set: {
                                secureURLexpiry: data.expiry
                            }
                        });
                    });
                }
            });
            return expenses;
        },
        'expensesCollection': function() {
            return Expenses;
        },
        'reimburseError': function() {
            return Session.get('reimburseError');
        }
    });
    Template.showExpensesToReimburse.events = {
        'click .reimburseCheckedExpensesButton': function(e) {
            var expenses, pin;
            expenses = $('.expenseToReimburseCheckbox:checked').map(function(el) {
                return this.value;
            }).get();
            pin = $('#PIN').val();
            Meteor.call('reimburseCheckedExpenses', expenses, pin, function(error, result) {
                if (error) {
                    Session.set('reimburseError', error.reason);
                }
                return $.unblockUI();
            });
            return $.blockUI({
                message: 'Making it rain.  Hold your horses...'
            });
        }
    };
    Template.displayExpenseRow.helpers({
        'currentExpense': function() {
            return Template.currentData();
        },
        'ableToApprove': function() {
            return (Template.currentData().status === 'PendingApproval') && Roles.userIsInRole(Meteor.user()._id, ['accountant', 'superAccountant', 'manager']);
        },
        'ableToReimburse': function() {
            return (Template.currentData().status === 'PendingReimbursement') && Roles.userIsInRole(Meteor.user()._id, ['accountant', 'superAccountant']);
        },
        'getEmployee': function() {
            var k;
            k = Meteor.users.findOne({
                _id: Template.currentData().employeeId
            });
            return k;
        }
    });
    Template.displayUHExpenseRow.events = {
        'click .unRejectExpenseButton': function(e) {
            var expense;
            expense = Template.currentData();
            return Expenses.update({
                _id: expense._id
            }, {
                $set: {
                    status: 'PendingApproval',
                    rejectedByUserId: Meteor.user()._id
                }
            });
        }
    };
    Template.displayUHExpenseRow.helpers({
        'currentExpense': function() {
            return Template.currentData();
        },
        'ableToApprove': function() {
            return (Template.currentData().status === 'PendingApproval') && Roles.userIsInRole(Meteor.user()._id, ['accountant', 'superAccountant', 'manager']);
        },
        'ableToUnReject': function() {
            return (Template.currentData().status === 'Rejected') && Roles.userIsInRole(Meteor.user()._id, ['accountant', 'superAccountant', 'manager']);
        },
        'getEmployee': function() {
            var k;
            k = Meteor.users.findOne({
                _id: Template.currentData().employeeId
            });
            return k;
        }
    });
    Template.displayExpenseRow.events = {
        'click .approveExpenseButton': function(e) {
            var expense;
            expense = Template.currentData();
            Expenses.update({
                _id: expense._id
            }, {
                $set: {
                    status: 'PendingReimbursement',
                    approvedByUserId: Meteor.user()._id
                }
            });
            return Meteor.call('sendMail', expense.employeeId, expense.type, 0);
        },
        'click .rejectExpenseButton': function(e) {
            var expense;
            expense = Template.currentData();
            Expenses.update({
                _id: expense._id
            }, {
                $set: {
                    status: 'Rejected',
                    rejectedByUserId: Meteor.user()._id
                }
            });
            return Meteor.call('sendMail', expense.employeeId, expense.type, 1);
        },
        'click .reimburseExpenseButton': function(e) {
            var expense;
            expense = Template.currentData();
            return Meteor.call('reimburseExpense', expense);
        }
    };
}

getQueryStringParam = function(sVar) {
    return unescape(window.location.search.replace(new RegExp("^(?:.*[&\\?]" + escape(sVar).replace(/[\.\+\*]/g, "\\$&") + "(?:\\=([^&]*))?)?.*$", "i"), "$1"));
};