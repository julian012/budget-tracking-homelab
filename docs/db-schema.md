# Database Schema — Budget Tracker

## `users` table

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| firebase_uid | VARCHAR(255) | NOT NULL UNIQUE | Firebase Auth ID |
| email | VARCHAR(255) | NULL | User email |
| name | VARCHAR(255) | NULL | User name |
| display_name | VARCHAR(255) | NULL | User's custom display name. Migration `003` |
| avatar | VARCHAR(255) | '👤' | Avatar emoji or URL. Migration `003` |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

## `categories` table

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| name | VARCHAR(255) | NOT NULL | Category name |
| icon | VARCHAR(50) | 'tag' | Emoji (1 char) or Lucide icon name |
| color | VARCHAR(20) | '#6B7280' | Hex color |
| type | SMALLINT | 0 | 0 = Variable, 1 = Fixed |
| requires_description | BOOLEAN | true | Whether the category requires a description when recording an expense |
| default_amount | DECIMAL(12,2) | 0 | Default amount (prefills expenses; 0 = no value). Migration `008` |
| user_id | UUID | NOT NULL | FK → users(id) |
| UNIQUE (name, user_id) | — | — | No two categories may share the same name for the same user |

## `expenses` table

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| user_id | UUID | NOT NULL | FK → users(id) |
| category_id | UUID | NULL | FK → categories(id) |
| card_id | UUID | NULL | FK → cards(id). NULL = cash/debit |
| amount | DECIMAL(12,2) | NOT NULL DEFAULT 0 | Expense amount |
| description | TEXT | NULL | Description |
| expense_date | DATE | NOT NULL DEFAULT CURRENT_DATE | Expense date |
| source | VARCHAR(50) | NOT NULL DEFAULT 'form' | Origin: form, camera, voice |
| receipt_url | TEXT | NULL | URL of the receipt photo in MinIO |
| audio_url | TEXT | NULL | URL of the voice note in MinIO |
| transaction_group_id | UUID | NULL | Groups split expenses generated from the same form. Migration `009` |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

### Indexes
- `idx_expenses_user_id` ON (user_id)
- `idx_expenses_date` ON (expense_date)
- `idx_expenses_category` ON (category_id)

### Enums
| type | Meaning |
|------|------------|
| 0 | Variable (discretionary expense) |
| 1 | Fixed (recurring monthly expense) |

## `cards` table

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| user_id | UUID | NOT NULL | FK → users(id) |
| name | VARCHAR(255) | NOT NULL | Card name (e.g. Visa Signature) |
| franchise | VARCHAR(20) | 'other' | Franchise: visa, mastercard, amex, diners, other |
| color | VARCHAR(20) | '#1A1C1E' | Base card color (hex) |
| cut_off_day | SMALLINT | 1 (CHECK 1-31) | Statement cut-off day |
| payment_day | SMALLINT | 1 (CHECK 1-31) | Payment due day |
| credit_limit | DECIMAL(12,2) | NULL | Card limit/cap (optional) |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

## `presets` table

Recurring expense templates (presets) for quick entry from the FAB. Migration `010`.

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| user_id | UUID | NOT NULL | FK → users(id) |
| name | VARCHAR(255) | NOT NULL | Template name (e.g. Bus pass) |
| icon | VARCHAR(50) | 'tag' | Emoji (1 char) or Lucide icon name |
| amount | DECIMAL(12,2) | NOT NULL DEFAULT 0 | Predefined amount |
| category_id | UUID | NULL | FK → categories(id) `ON DELETE SET NULL` |
| card_id | UUID | NULL | FK → cards(id) `ON DELETE SET NULL`. NULL = cash |
| description | TEXT | NULL | Predefined description |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

### Indexes
- `idx_presets_user_id` ON (user_id)

## `people` table

Local contacts for shared expenses. Migration `011`.

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| user_id | UUID | NOT NULL | FK → users(id) |
| name | VARCHAR(255) | NOT NULL | Person's name (e.g. Roomie) |
| color | VARCHAR(20) | '#6B7280' | Hex color for the avatar |
| icon | VARCHAR(50) | '👤' | Emoji or icon name |
| archived | BOOLEAN | NOT NULL DEFAULT false | Whether it's archived (hidden from new expenses) |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

### Indexes
- `idx_people_user_id_archived` ON (user_id, archived)

## `expense_shares` table

People's shares in a shared expense. Migration `011`.

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| expense_id | UUID | NOT NULL | FK → expenses(id) ON DELETE CASCADE |
| person_id | UUID | NOT NULL | FK → people(id) ON DELETE RESTRICT |
| amount | DECIMAL(12,2) | NOT NULL | Amount owed by the person |
| paid_amount | DECIMAL(12,2) | NOT NULL DEFAULT 0 | Amount already paid (FIFO) |
| pending_amount | DECIMAL(12,2) | NOT NULL GENERATED | `amount - paid_amount` |
| settled | BOOLEAN | NOT NULL DEFAULT false | `true` when `paid_amount >= amount` |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

### Indexes
- `idx_expense_shares_expense_id` ON (expense_id)
- `idx_expense_shares_person_id` ON (person_id)

## `person_payments` table

Payments received from a person (lump sums, later allocated via FIFO). Migration `011`.

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| person_id | UUID | NOT NULL | FK → people(id) ON DELETE RESTRICT |
| user_id | UUID | NOT NULL | FK → users(id) |
| amount | DECIMAL(12,2) | NOT NULL | Total payment amount |
| paid_at | DATE | NOT NULL | Date the payment was received |
| note | TEXT | NULL | Optional note |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

## `payment_allocations` table

FIFO allocation of a payment to specific shares. Migration `011`.

| Column | Type | Default | Description |
|---------|------|---------|-------------|
| id | UUID | gen_random_uuid() | Primary key |
| payment_id | UUID | NOT NULL | FK → person_payments(id) ON DELETE CASCADE |
| share_id | UUID | NOT NULL | FK → expense_shares(id) ON DELETE RESTRICT |
| amount | DECIMAL(12,2) | NOT NULL | Amount allocated to this share |
| created_at | TIMESTAMPTZ | NOW() | Creation date |

### Indexes
- `idx_payment_allocations_payment_id` ON (payment_id)
- `idx_payment_allocations_share_id` ON (share_id)
