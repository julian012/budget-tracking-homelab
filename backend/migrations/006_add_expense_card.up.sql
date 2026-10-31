ALTER TABLE expenses ADD COLUMN IF NOT EXISTS card_id UUID REFERENCES cards(id);
CREATE INDEX IF NOT EXISTS idx_expenses_card_id ON expenses(card_id);
