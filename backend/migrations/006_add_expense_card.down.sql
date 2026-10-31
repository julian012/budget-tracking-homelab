DROP INDEX IF EXISTS idx_expenses_card_id;
ALTER TABLE expenses DROP COLUMN IF EXISTS card_id;
