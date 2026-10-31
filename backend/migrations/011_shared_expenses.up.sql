CREATE TABLE IF NOT EXISTS people (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(20) NOT NULL DEFAULT '#6B7280',
    icon VARCHAR(50) NOT NULL DEFAULT 'user',
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS people_user_name_unique
    ON people(user_id, LOWER(name))
    WHERE archived = FALSE;

CREATE INDEX IF NOT EXISTS idx_people_user_id ON people(user_id);

CREATE TABLE IF NOT EXISTS expense_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID REFERENCES expenses(id) ON DELETE CASCADE NOT NULL,
    person_id UUID REFERENCES people(id) ON DELETE RESTRICT NOT NULL,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(expense_id, person_id)
);

CREATE INDEX IF NOT EXISTS idx_expense_shares_expense ON expense_shares(expense_id);
CREATE INDEX IF NOT EXISTS idx_expense_shares_person ON expense_shares(person_id);

CREATE TABLE IF NOT EXISTS person_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES people(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    paid_at DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_person_payments_person ON person_payments(person_id);

CREATE TABLE IF NOT EXISTS payment_allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID REFERENCES person_payments(id) ON DELETE CASCADE NOT NULL,
    share_id UUID REFERENCES expense_shares(id) ON DELETE CASCADE NOT NULL,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    UNIQUE(payment_id, share_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment ON payment_allocations(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_share ON payment_allocations(share_id);
