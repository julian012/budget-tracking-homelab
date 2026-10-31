DROP INDEX IF EXISTS idx_payment_allocations_share;
DROP INDEX IF EXISTS idx_payment_allocations_payment;
DROP TABLE IF EXISTS payment_allocations;

DROP INDEX IF EXISTS idx_person_payments_person;
DROP TABLE IF EXISTS person_payments;

DROP INDEX IF EXISTS idx_expense_shares_person;
DROP INDEX IF EXISTS idx_expense_shares_expense;
DROP TABLE IF EXISTS expense_shares;

DROP INDEX IF EXISTS idx_people_user_id;
DROP INDEX IF EXISTS people_user_name_unique;
DROP TABLE IF EXISTS people;
