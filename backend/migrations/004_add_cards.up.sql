CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) NOT NULL,
    name VARCHAR(255) NOT NULL,
    cut_off_day SMALLINT NOT NULL DEFAULT 1 CHECK (cut_off_day BETWEEN 1 AND 31),
    payment_day SMALLINT NOT NULL DEFAULT 1 CHECK (payment_day BETWEEN 1 AND 31),
    credit_limit DECIMAL(12,2),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cards_user_id ON cards(user_id);
