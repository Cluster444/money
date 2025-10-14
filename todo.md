## WIP

[ ] - Implement loan account type
[ ] - Implement cashflow loan account type

## Done

[x] - Add posted_balance, pending_balance functions
[x] - Validate cash account is not negative (credits > debits)
[x] - Transfer Validate debit account != credit account
[x] - Add post! function to Transfer that transitions from pending to posted
[x] - Add posted, pending scopes to transfer model
[x] - Add scopes for all account kinds to Account model
[x] - Ensure validates for posted status like posted_on is set
[x] - Schedule needs ability to provide planned occurrance dates
[x] - Schedule validation of period/frequency
[x] - Schedule validation that if ends_on is set, there's a period and frequency
[x] - Generate planned transfers up to date
[x] - Add a planned_balance(date) function
[x] - Materialize planned transfers to pending for today (Job)
[x] - Implement credit account type
[x] - Create an Account controller
