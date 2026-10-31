package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/models"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ExpenseRepo interface {
	Create(ctx context.Context, expense *models.Expense) error
	CreateUser(ctx context.Context, user *models.User) error
	GetUserByFirebaseUID(ctx context.Context, uid string) (*models.User, error)
	GetUserByID(ctx context.Context, id string) (*models.User, error)
	UpdateUserProfile(ctx context.Context, user *models.User) error
	GetExpenses(ctx context.Context, userID string, startDate, endDate time.Time, categoryID string) ([]models.Expense, error)
	GetExpenseByID(ctx context.Context, id, userID string) (*models.Expense, error)
	UpdateExpense(ctx context.Context, expense *models.Expense) error
	DeleteExpense(ctx context.Context, id, userID string) error
	GetCategories(ctx context.Context, userID string) ([]models.Category, error)
	GetCategoryByID(ctx context.Context, id, userID string) (*models.Category, error)
	CreateCategory(ctx context.Context, category *models.Category) error
	UpdateCategory(ctx context.Context, category *models.Category) error
	DeleteCategory(ctx context.Context, id, userID string) error
	CreateCard(ctx context.Context, card *models.Card) error
	GetCards(ctx context.Context, userID string) ([]models.Card, error)
	GetCardByID(ctx context.Context, id, userID string) (*models.Card, error)
	UpdateCard(ctx context.Context, card *models.Card) error
	DeleteCard(ctx context.Context, id, userID string) error
	GetPresets(ctx context.Context, userID string) ([]models.Preset, error)
	GetPresetByID(ctx context.Context, id, userID string) (*models.Preset, error)
	CreatePreset(ctx context.Context, preset *models.Preset) error
	UpdatePreset(ctx context.Context, preset *models.Preset) error
	DeletePreset(ctx context.Context, id, userID string) error
	GetStats(ctx context.Context, userID string, startDate, endDate time.Time, expenseType string) (*models.StatsSummary, error)

	// People
	CreatePerson(ctx context.Context, person *models.Person) error
	ListPeople(ctx context.Context, userID string, includeArchived bool) ([]models.Person, error)
	GetPersonByID(ctx context.Context, id, userID string) (*models.Person, error)
	UpdatePerson(ctx context.Context, person *models.Person) error
	ArchivePerson(ctx context.Context, id, userID string, archived bool) error
	DeletePerson(ctx context.Context, id, userID string) error
	CountPersonShares(ctx context.Context, id, userID string) (int, error)
	CountPersonPayments(ctx context.Context, id, userID string) (int, error)
	GetPersonPendingTotal(ctx context.Context, id, userID string) (float64, error)

	// Shared expense shares
	ReplaceExpenseShares(ctx context.Context, expenseID, userID string, shares []models.ExpenseShareInput) error
	GetSharesByPerson(ctx context.Context, personID, userID, status string) ([]models.PersonShareExpense, error)
	CountPaymentAllocationsForExpense(ctx context.Context, expenseID, userID string) (int, error)

	// Payments
	CreatePersonPayment(ctx context.Context, personID, userID string, amount float64, paidAt, note string) (*models.PersonPayment, error)
	DeletePersonPayment(ctx context.Context, id, userID string) error
	ListPersonPayments(ctx context.Context, personID, userID string) ([]models.PersonPayment, error)

	// Shared summary
	GetSharedSummary(ctx context.Context, userID string) (*models.SharedSummary, error)
}

type PostgresRepo struct {
	pool *pgxpool.Pool
}

func NewPostgresRepo(dbURL string) (*PostgresRepo, error) {
	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		return nil, fmt.Errorf("unable to connect to database: %w", err)
	}
	return &PostgresRepo{pool: pool}, nil
}

func (r *PostgresRepo) Close() {
	r.pool.Close()
}

func (r *PostgresRepo) Pool() *pgxpool.Pool {
	return r.pool
}

func (r *PostgresRepo) Create(ctx context.Context, expense *models.Expense) error {
	query := `INSERT INTO expenses (user_id, category_id, card_id, amount, description, expense_date, source, receipt_url, audio_url, transaction_group_id)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING id, created_at`
	return r.pool.QueryRow(ctx, query,
		expense.UserID, expense.CategoryID, expense.CardID, expense.Amount, expense.Description,
		expense.ExpenseDate, expense.Source, expense.ReceiptURL, expense.AudioURL, expense.TransactionGroupID,
	).Scan(&expense.ID, &expense.CreatedAt)
}

func (r *PostgresRepo) CreateUser(ctx context.Context, user *models.User) error {
	query := `INSERT INTO users (firebase_uid, email, name, display_name, avatar) VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (firebase_uid) DO UPDATE SET email = COALESCE($2, users.email), name = COALESCE($3, users.name)
		RETURNING id, created_at`
	return r.pool.QueryRow(ctx, query, user.FirebaseUID, user.Email, user.Name, user.DisplayName, user.Avatar).Scan(&user.ID, &user.CreatedAt)
}

func (r *PostgresRepo) GetUserByFirebaseUID(ctx context.Context, uid string) (*models.User, error) {
	user := &models.User{}
	err := r.pool.QueryRow(ctx,
		"SELECT id, firebase_uid, email, name, COALESCE(display_name, ''), COALESCE(avatar, ''), created_at FROM users WHERE firebase_uid = $1", uid,
	).Scan(&user.ID, &user.FirebaseUID, &user.Email, &user.Name, &user.DisplayName, &user.Avatar, &user.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	return user, nil
}

func (r *PostgresRepo) GetUserByID(ctx context.Context, id string) (*models.User, error) {
	user := &models.User{}
	err := r.pool.QueryRow(ctx,
		"SELECT id, firebase_uid, email, name, COALESCE(display_name, ''), COALESCE(avatar, ''), created_at FROM users WHERE id = $1", id,
	).Scan(&user.ID, &user.FirebaseUID, &user.Email, &user.Name, &user.DisplayName, &user.Avatar, &user.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	return user, nil
}

func (r *PostgresRepo) UpdateUserProfile(ctx context.Context, user *models.User) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE users SET display_name=$1, avatar=$2 WHERE id=$3",
		user.DisplayName, user.Avatar, user.ID)
	return err
}

func (r *PostgresRepo) GetExpenses(ctx context.Context, userID string, startDate, endDate time.Time, categoryID string) ([]models.Expense, error) {
	query := `SELECT e.id, e.user_id, e.category_id, e.card_id, e.amount, e.description, e.expense_date, e.source, 
		COALESCE(e.receipt_url, ''), COALESCE(e.audio_url, ''), e.transaction_group_id, e.created_at,
		c.id, c.name, c.icon, c.color, COALESCE(c.type, 0), c.user_id,
		k.id, COALESCE(k.name, ''), COALESCE(k.franchise, ''), COALESCE(k.color, ''), COALESCE(k.cut_off_day, 1), COALESCE(k.payment_day, 1), k.credit_limit, COALESCE(k.created_at, '1970-01-01'::timestamptz)
		FROM expenses e LEFT JOIN categories c ON e.category_id = c.id
		LEFT JOIN cards k ON e.card_id = k.id
		WHERE e.user_id = $1`
	args := []interface{}{userID}
	argIdx := 2

	if !startDate.IsZero() {
		query += fmt.Sprintf(" AND e.expense_date >= $%d", argIdx)
		args = append(args, startDate)
		argIdx++
	}
	if !endDate.IsZero() {
		query += fmt.Sprintf(" AND e.expense_date <= $%d", argIdx)
		args = append(args, endDate)
		argIdx++
	}
	if categoryID != "" {
		query += fmt.Sprintf(" AND e.category_id = $%d", argIdx)
		args = append(args, categoryID)
		argIdx++
	}

	query += " ORDER BY e.expense_date DESC, e.created_at DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("query expenses: %w", err)
	}
	defer rows.Close()

	var expenses []models.Expense
	for rows.Next() {
		var e models.Expense
		var c models.Category
		var k models.Card
		var kID *string
		e.Category = &c
		if err := rows.Scan(&e.ID, &e.UserID, &e.CategoryID, &e.CardID, &e.Amount, &e.Description, &e.ExpenseDate,
			&e.Source, &e.ReceiptURL, &e.AudioURL, &e.TransactionGroupID, &e.CreatedAt,
			&c.ID, &c.Name, &c.Icon, &c.Color, &c.Type, &c.UserID,
			&kID, &k.Name, &k.Franchise, &k.Color, &k.CutOffDay, &k.PaymentDay, &k.CreditLimit, &k.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan expense: %w", err)
		}
		if kID != nil {
			k.ID = *kID
			k.UserID = userID
			e.Card = &k
		}
		expenses = append(expenses, e)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := r.attachShares(ctx, expenses, userID); err != nil {
		return nil, err
	}
	return expenses, nil
}

func (r *PostgresRepo) GetExpenseByID(ctx context.Context, id, userID string) (*models.Expense, error) {
	e := &models.Expense{Category: &models.Category{}}
	var k models.Card
	var kID *string
	err := r.pool.QueryRow(ctx,
		`SELECT e.id, e.user_id, e.category_id, e.card_id, e.amount, e.description, e.expense_date, e.source, 
			COALESCE(e.receipt_url, ''), COALESCE(e.audio_url, ''), e.transaction_group_id, e.created_at,
			c.id, c.name, c.icon, c.color, COALESCE(c.type, 0), c.user_id,
			k.id, COALESCE(k.name, ''), COALESCE(k.franchise, ''), COALESCE(k.color, ''), COALESCE(k.cut_off_day, 1), COALESCE(k.payment_day, 1), k.credit_limit, COALESCE(k.created_at, '1970-01-01'::timestamptz)
		FROM expenses e LEFT JOIN categories c ON e.category_id = c.id
		LEFT JOIN cards k ON e.card_id = k.id
		WHERE e.id = $1 AND e.user_id = $2`, id, userID,
	).Scan(&e.ID, &e.UserID, &e.CategoryID, &e.CardID, &e.Amount, &e.Description, &e.ExpenseDate,
		&e.Source, &e.ReceiptURL, &e.AudioURL, &e.TransactionGroupID, &e.CreatedAt,
		&e.Category.ID, &e.Category.Name, &e.Category.Icon, &e.Category.Color, &e.Category.Type, &e.Category.UserID,
		&kID, &k.Name, &k.Franchise, &k.Color, &k.CutOffDay, &k.PaymentDay, &k.CreditLimit, &k.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("expense not found: %w", err)
	}
	if kID != nil {
		k.ID = *kID
		k.UserID = userID
		e.Card = &k
	}
	wrapped := []models.Expense{*e}
	if err := r.attachShares(ctx, wrapped, userID); err != nil {
		return nil, err
	}
	e.Shares = wrapped[0].Shares
	return e, nil
}

func (r *PostgresRepo) UpdateExpense(ctx context.Context, expense *models.Expense) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE expenses SET category_id=$1, card_id=$2, amount=$3, description=$4, expense_date=$5, source=$6
		WHERE id=$7 AND user_id=$8`,
		expense.CategoryID, expense.CardID, expense.Amount, expense.Description, expense.ExpenseDate, expense.Source,
		expense.ID, expense.UserID)
	return err
}

func (r *PostgresRepo) DeleteExpense(ctx context.Context, id, userID string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM expenses WHERE id=$1 AND user_id=$2", id, userID)
	return err
}

func (r *PostgresRepo) GetCategories(ctx context.Context, userID string) ([]models.Category, error) {
	rows, err := r.pool.Query(ctx, "SELECT id, name, icon, color, COALESCE(type, 0), COALESCE(requires_description, true), COALESCE(default_amount, 0), user_id FROM categories WHERE user_id=$1 ORDER BY LOWER(name)", userID)
	if err != nil {
		return nil, fmt.Errorf("query categories: %w", err)
	}
	defer rows.Close()

	var categories []models.Category
	for rows.Next() {
		var c models.Category
		if err := rows.Scan(&c.ID, &c.Name, &c.Icon, &c.Color, &c.Type, &c.RequiresDescription, &c.DefaultAmount, &c.UserID); err != nil {
			return nil, fmt.Errorf("scan category: %w", err)
		}
		categories = append(categories, c)
	}
	return categories, rows.Err()
}

func (r *PostgresRepo) GetCategoryByID(ctx context.Context, id, userID string) (*models.Category, error) {
	c := &models.Category{}
	err := r.pool.QueryRow(ctx,
		"SELECT id, name, icon, color, COALESCE(type, 0), COALESCE(requires_description, true), COALESCE(default_amount, 0), user_id FROM categories WHERE id=$1 AND user_id=$2", id, userID,
	).Scan(&c.ID, &c.Name, &c.Icon, &c.Color, &c.Type, &c.RequiresDescription, &c.DefaultAmount, &c.UserID)
	if err != nil {
		return nil, fmt.Errorf("category not found: %w", err)
	}
	return c, nil
}

func (r *PostgresRepo) CreateCategory(ctx context.Context, category *models.Category) error {
	return r.pool.QueryRow(ctx,
		"INSERT INTO categories (name, icon, color, type, requires_description, default_amount, user_id) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id",
		category.Name, category.Icon, category.Color, category.Type, category.RequiresDescription, category.DefaultAmount, category.UserID,
	).Scan(&category.ID)
}

func (r *PostgresRepo) UpdateCategory(ctx context.Context, category *models.Category) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE categories SET name=$1, icon=$2, color=$3, type=$4, requires_description=$5, default_amount=$6 WHERE id=$7 AND user_id=$8",
		category.Name, category.Icon, category.Color, category.Type, category.RequiresDescription, category.DefaultAmount, category.ID, category.UserID)
	return err
}

func (r *PostgresRepo) DeleteCategory(ctx context.Context, id, userID string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM categories WHERE id=$1 AND user_id=$2", id, userID)
	return err
}

func (r *PostgresRepo) GetStats(ctx context.Context, userID string, startDate, endDate time.Time, expenseType string) (*models.StatsSummary, error) {
	stats := &models.StatsSummary{}

	query := `SELECT c.id, c.name, COALESCE(SUM(e.amount), 0) AS total, COUNT(e.id), c.icon, c.color, COALESCE(c.type, 0)
		FROM categories c
		LEFT JOIN expenses e ON c.id = e.category_id AND e.user_id = $1`
	args := []interface{}{userID}
	argIdx := 2

	if !startDate.IsZero() {
		query += fmt.Sprintf(" AND e.expense_date >= $%d", argIdx)
		args = append(args, startDate)
		argIdx++
	}
	if !endDate.IsZero() {
		query += fmt.Sprintf(" AND e.expense_date <= $%d", argIdx)
		args = append(args, endDate)
		argIdx++
	}

	query += " WHERE c.user_id = $1"
	if expenseType != "" {
		query += fmt.Sprintf(" AND c.type = $%d", argIdx)
		args = append(args, typeValue(expenseType))
		argIdx++
	}
	query += " GROUP BY c.id, c.name, c.icon, c.color, c.type ORDER BY total DESC"

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("stats by category: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var ct models.CategoryTotal
		if err := rows.Scan(&ct.CategoryID, &ct.CategoryName, &ct.Total, &ct.Count, &ct.Icon, &ct.Color, &ct.Type); err != nil {
			return nil, err
		}
		stats.ByCategory = append(stats.ByCategory, ct)
		stats.Total += ct.Total
	}

	payQuery := `SELECT e.card_id, COALESCE(k.name, 'Efectivo'), COALESCE(k.franchise, ''), COALESCE(k.color, ''),
		COALESCE(SUM(e.amount), 0) AS total, COUNT(e.id)
		FROM expenses e LEFT JOIN cards k ON e.card_id = k.id
		JOIN categories c ON e.category_id = c.id
		WHERE e.user_id = $1`
	payArgs := []interface{}{userID}
	payArgIdx := 2

	if !startDate.IsZero() {
		payQuery += fmt.Sprintf(" AND e.expense_date >= $%d", payArgIdx)
		payArgs = append(payArgs, startDate)
		payArgIdx++
	}
	if !endDate.IsZero() {
		payQuery += fmt.Sprintf(" AND e.expense_date <= $%d", payArgIdx)
		payArgs = append(payArgs, endDate)
		payArgIdx++
	}
	if expenseType != "" {
		payQuery += fmt.Sprintf(" AND c.type = $%d", payArgIdx)
		payArgs = append(payArgs, typeValue(expenseType))
		payArgIdx++
	}

	payQuery += " GROUP BY e.card_id, k.name, k.franchise, k.color ORDER BY total DESC"

	payRows, err := r.pool.Query(ctx, payQuery, payArgs...)
	if err != nil {
		return nil, fmt.Errorf("stats by payment: %w", err)
	}
	defer payRows.Close()

	for payRows.Next() {
		var pt models.PaymentTotal
		var cardID *string
		if err := payRows.Scan(&cardID, &pt.Name, &pt.Franchise, &pt.Color, &pt.Total, &pt.Count); err != nil {
			return nil, err
		}
		pt.CardID = cardID
		stats.ByPayment = append(stats.ByPayment, pt)
	}

	monthQuery := `SELECT TO_CHAR(e.expense_date, 'YYYY-MM'), SUM(e.amount)
		FROM expenses e JOIN categories c ON e.category_id = c.id
		WHERE e.user_id = $1`
	monthArgs := []interface{}{userID}
	monthArgIdx := 2

	if !startDate.IsZero() {
		monthQuery += fmt.Sprintf(" AND e.expense_date >= $%d", monthArgIdx)
		monthArgs = append(monthArgs, startDate)
		monthArgIdx++
	}
	if !endDate.IsZero() {
		monthQuery += fmt.Sprintf(" AND e.expense_date <= $%d", monthArgIdx)
		monthArgs = append(monthArgs, endDate)
		monthArgIdx++
	}
	if expenseType != "" {
		monthQuery += fmt.Sprintf(" AND c.type = $%d", monthArgIdx)
		monthArgs = append(monthArgs, typeValue(expenseType))
		monthArgIdx++
	}

	monthQuery += " GROUP BY TO_CHAR(e.expense_date, 'YYYY-MM') ORDER BY 1 DESC LIMIT 12"

	monthRows, err := r.pool.Query(ctx, monthQuery, monthArgs...)
	if err != nil {
		return nil, fmt.Errorf("stats by month: %w", err)
	}
	defer monthRows.Close()

	for monthRows.Next() {
		var mt models.MonthTotal
		if err := monthRows.Scan(&mt.Month, &mt.Total); err != nil {
			return nil, err
		}
		stats.ByMonth = append(stats.ByMonth, mt)
	}

	countQuery := `SELECT
		COUNT(*) FILTER (WHERE e.card_id IS NULL),
		COUNT(*) FILTER (WHERE e.card_id IS NOT NULL)
		FROM expenses e JOIN categories c ON e.category_id = c.id
		WHERE e.user_id = $1`
	countArgs := []interface{}{userID}
	countArgIdx := 2

	if !startDate.IsZero() {
		countQuery += fmt.Sprintf(" AND e.expense_date >= $%d", countArgIdx)
		countArgs = append(countArgs, startDate)
		countArgIdx++
	}
	if !endDate.IsZero() {
		countQuery += fmt.Sprintf(" AND e.expense_date <= $%d", countArgIdx)
		countArgs = append(countArgs, endDate)
		countArgIdx++
	}
	if expenseType != "" {
		countQuery += fmt.Sprintf(" AND c.type = $%d", countArgIdx)
		countArgs = append(countArgs, typeValue(expenseType))
	}

	if err := r.pool.QueryRow(ctx, countQuery, countArgs...).Scan(&stats.CashCount, &stats.CardCount); err != nil {
		return nil, fmt.Errorf("stats payment counts: %w", err)
	}

	return stats, nil
}

func typeValue(expenseType string) int {
	if expenseType == "fixed" {
		return 1
	}
	if expenseType == "variable" {
		return 0
	}
	return -1
}

func (r *PostgresRepo) CreateCard(ctx context.Context, card *models.Card) error {
	return r.pool.QueryRow(ctx,
		"INSERT INTO cards (user_id, name, franchise, color, cut_off_day, payment_day, credit_limit) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, created_at",
		card.UserID, card.Name, card.Franchise, card.Color, card.CutOffDay, card.PaymentDay, card.CreditLimit,
	).Scan(&card.ID, &card.CreatedAt)
}

func (r *PostgresRepo) GetCards(ctx context.Context, userID string) ([]models.Card, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT id, user_id, name, franchise, color, cut_off_day, payment_day, credit_limit, created_at FROM cards WHERE user_id=$1 ORDER BY created_at DESC", userID)
	if err != nil {
		return nil, fmt.Errorf("query cards: %w", err)
	}
	defer rows.Close()

	var cards []models.Card
	for rows.Next() {
		var c models.Card
		if err := rows.Scan(&c.ID, &c.UserID, &c.Name, &c.Franchise, &c.Color, &c.CutOffDay, &c.PaymentDay, &c.CreditLimit, &c.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan card: %w", err)
		}
		cards = append(cards, c)
	}
	return cards, rows.Err()
}

func (r *PostgresRepo) GetCardByID(ctx context.Context, id, userID string) (*models.Card, error) {
	card := &models.Card{}
	err := r.pool.QueryRow(ctx,
		"SELECT id, user_id, name, franchise, color, cut_off_day, payment_day, credit_limit, created_at FROM cards WHERE id=$1 AND user_id=$2", id, userID,
	).Scan(&card.ID, &card.UserID, &card.Name, &card.Franchise, &card.Color, &card.CutOffDay, &card.PaymentDay, &card.CreditLimit, &card.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("card not found: %w", err)
	}
	return card, nil
}

func (r *PostgresRepo) UpdateCard(ctx context.Context, card *models.Card) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE cards SET name=$1, franchise=$2, color=$3, cut_off_day=$4, payment_day=$5, credit_limit=$6 WHERE id=$7 AND user_id=$8",
		card.Name, card.Franchise, card.Color, card.CutOffDay, card.PaymentDay, card.CreditLimit, card.ID, card.UserID)
	return err
}

func (r *PostgresRepo) DeleteCard(ctx context.Context, id, userID string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM cards WHERE id=$1 AND user_id=$2", id, userID)
	return err
}

const presetColumns = `id, user_id, name, COALESCE(icon, 'tag'), COALESCE(amount, 0),
	COALESCE(category_id::text, ''), card_id, COALESCE(description, ''), created_at`

func (r *PostgresRepo) GetPresets(ctx context.Context, userID string) ([]models.Preset, error) {
	rows, err := r.pool.Query(ctx,
		"SELECT "+presetColumns+" FROM presets WHERE user_id=$1 ORDER BY created_at DESC", userID)
	if err != nil {
		return nil, fmt.Errorf("query presets: %w", err)
	}
	defer rows.Close()

	var presets []models.Preset
	for rows.Next() {
		var p models.Preset
		if err := rows.Scan(&p.ID, &p.UserID, &p.Name, &p.Icon, &p.Amount, &p.CategoryID, &p.CardID, &p.Description, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan preset: %w", err)
		}
		presets = append(presets, p)
	}
	return presets, rows.Err()
}

func (r *PostgresRepo) GetPresetByID(ctx context.Context, id, userID string) (*models.Preset, error) {
	p := &models.Preset{}
	err := r.pool.QueryRow(ctx,
		"SELECT "+presetColumns+" FROM presets WHERE id=$1 AND user_id=$2", id, userID,
	).Scan(&p.ID, &p.UserID, &p.Name, &p.Icon, &p.Amount, &p.CategoryID, &p.CardID, &p.Description, &p.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("preset not found: %w", err)
	}
	return p, nil
}

func (r *PostgresRepo) CreatePreset(ctx context.Context, preset *models.Preset) error {
	return r.pool.QueryRow(ctx,
		`INSERT INTO presets (user_id, name, icon, amount, category_id, card_id, description)
		VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, created_at`,
		preset.UserID, preset.Name, preset.Icon, preset.Amount, nullableString(preset.CategoryID), preset.CardID, preset.Description,
	).Scan(&preset.ID, &preset.CreatedAt)
}

func (r *PostgresRepo) UpdatePreset(ctx context.Context, preset *models.Preset) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE presets SET name=$1, icon=$2, amount=$3, category_id=$4, card_id=$5, description=$6
		WHERE id=$7 AND user_id=$8`,
		preset.Name, preset.Icon, preset.Amount, nullableString(preset.CategoryID), preset.CardID, preset.Description, preset.ID, preset.UserID)
	return err
}

func (r *PostgresRepo) DeletePreset(ctx context.Context, id, userID string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM presets WHERE id=$1 AND user_id=$2", id, userID)
	return err
}

// nullableString convierte "" en NULL para columnas UUID opcionales (category_id
// de presets): Postgres rechaza "" como UUID.
func nullableString(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

// attachShares carga las participaciones de un listado de gastos y las asigna
// a cada gasto. No modifica el orden de la lista.
func (r *PostgresRepo) attachShares(ctx context.Context, expenses []models.Expense, userID string) error {
	if len(expenses) == 0 {
		return nil
	}
	idxByID := make(map[string]int, len(expenses))
	args := make([]interface{}, 0, len(expenses)+1)
	args = append(args, userID)
	for i, e := range expenses {
		idxByID[e.ID] = i
		args = append(args, e.ID)
	}

	placeholders := make([]string, len(expenses))
	for i := range expenses {
		placeholders[i] = fmt.Sprintf("$%d", i+2)
	}
	inClause := strings.Join(placeholders, ",")

	query := fmt.Sprintf(`SELECT s.id, s.expense_id, s.person_id, s.amount, COALESCE(SUM(a.amount), 0),
		p.id, p.name, p.color, p.icon, p.archived, p.created_at
	FROM expense_shares s
	JOIN people p ON s.person_id = p.id
	LEFT JOIN payment_allocations a ON a.share_id = s.id
	WHERE p.user_id = $1 AND s.expense_id IN (%s)
	GROUP BY s.id, s.expense_id, s.person_id, s.amount, p.id, p.name, p.color, p.icon, p.archived, p.created_at
	ORDER BY s.expense_id, s.created_at`, inClause)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("query shares: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var sh models.ExpenseShare
		var p models.Person
		var paid float64
		var expenseID string
		if err := rows.Scan(&sh.ID, &expenseID, &sh.PersonID, &sh.Amount, &paid,
			&p.ID, &p.Name, &p.Color, &p.Icon, &p.Archived, &p.CreatedAt); err != nil {
			return fmt.Errorf("scan share: %w", err)
		}
		sh.Person = &p
		sh.PaidAmount = paid
		sh.PendingAmount = sh.Amount - paid
		sh.Settled = paid >= sh.Amount
		i, ok := idxByID[expenseID]
		if !ok {
			continue
		}
		expenses[i].Shares = append(expenses[i].Shares, sh)
	}
	return rows.Err()
}

func (r *PostgresRepo) CreatePerson(ctx context.Context, person *models.Person) error {
	return r.pool.QueryRow(ctx,
		`INSERT INTO people (user_id, name, color, icon, archived) VALUES ($1, $2, $3, $4, $5) RETURNING id, created_at`,
		person.UserID, person.Name, person.Color, person.Icon, person.Archived,
	).Scan(&person.ID, &person.CreatedAt)
}

func (r *PostgresRepo) ListPeople(ctx context.Context, userID string, includeArchived bool) ([]models.Person, error) {
	query := "SELECT id, user_id, name, color, icon, archived, created_at FROM people WHERE user_id=$1"
	if !includeArchived {
		query += " AND archived = false"
	}
	query += " ORDER BY LOWER(name)"
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("query people: %w", err)
	}
	defer rows.Close()

	var people []models.Person
	for rows.Next() {
		var p models.Person
		if err := rows.Scan(&p.ID, &p.UserID, &p.Name, &p.Color, &p.Icon, &p.Archived, &p.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan person: %w", err)
		}
		people = append(people, p)
	}
	return people, rows.Err()
}

func (r *PostgresRepo) GetPersonByID(ctx context.Context, id, userID string) (*models.Person, error) {
	p := &models.Person{}
	err := r.pool.QueryRow(ctx,
		"SELECT id, user_id, name, color, icon, archived, created_at FROM people WHERE id=$1 AND user_id=$2", id, userID,
	).Scan(&p.ID, &p.UserID, &p.Name, &p.Color, &p.Icon, &p.Archived, &p.CreatedAt)
	if err != nil {
		return nil, fmt.Errorf("person not found: %w", err)
	}
	return p, nil
}

func (r *PostgresRepo) UpdatePerson(ctx context.Context, person *models.Person) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE people SET name=$1, color=$2, icon=$3 WHERE id=$4 AND user_id=$5",
		person.Name, person.Color, person.Icon, person.ID, person.UserID)
	return err
}

func (r *PostgresRepo) ArchivePerson(ctx context.Context, id, userID string, archived bool) error {
	_, err := r.pool.Exec(ctx,
		"UPDATE people SET archived=$1 WHERE id=$2 AND user_id=$3",
		archived, id, userID)
	return err
}

func (r *PostgresRepo) DeletePerson(ctx context.Context, id, userID string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM people WHERE id=$1 AND user_id=$2", id, userID)
	return err
}

func (r *PostgresRepo) CountPersonShares(ctx context.Context, id, userID string) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM expense_shares s JOIN people p ON s.person_id=p.id WHERE s.person_id=$1 AND p.user_id=$2`, id, userID,
	).Scan(&count)
	return count, err
}

func (r *PostgresRepo) CountPersonPayments(ctx context.Context, id, userID string) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM person_payments pay JOIN people p ON pay.person_id=p.id WHERE pay.person_id=$1 AND p.user_id=$2`, id, userID,
	).Scan(&count)
	return count, err
}

func (r *PostgresRepo) GetPersonPendingTotal(ctx context.Context, id, userID string) (float64, error) {
	var pending float64
	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(s.amount - COALESCE(a.amount, 0)), 0)
		FROM expense_shares s
		JOIN expenses e ON s.expense_id = e.id
		JOIN people p ON s.person_id = p.id
		LEFT JOIN payment_allocations a ON a.share_id = s.id
		WHERE s.person_id=$1 AND p.user_id=$2`, id, userID,
	).Scan(&pending)
	return pending, err
}

func (r *PostgresRepo) CountPaymentAllocationsForExpense(ctx context.Context, expenseID, userID string) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM payment_allocations a
		JOIN expense_shares s ON a.share_id = s.id
		JOIN expenses e ON s.expense_id = e.id
		WHERE e.id=$1 AND e.user_id=$2`, expenseID, userID,
	).Scan(&count)
	return count, err
}

func (r *PostgresRepo) ReplaceExpenseShares(ctx context.Context, expenseID, userID string, shares []models.ExpenseShareInput) error {
	if len(shares) == 0 {
		_, err := r.pool.Exec(ctx,
			`DELETE FROM expense_shares s USING expenses e WHERE s.expense_id=$1 AND e.id=s.expense_id AND e.user_id=$2`,
			expenseID, userID)
		return err
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	existingRows, err := tx.Query(ctx,
		`SELECT s.id, s.person_id, s.amount,
			COALESCE((SELECT SUM(a.amount) FROM payment_allocations a WHERE a.share_id = s.id), 0)
		FROM expense_shares s
		JOIN expenses e ON s.expense_id = e.id
		WHERE s.expense_id=$1 AND e.user_id=$2
		ORDER BY s.id
		FOR UPDATE OF s`, expenseID, userID)
	if err != nil {
		return fmt.Errorf("lock shares: %w", err)
	}

	type existingShare struct {
		id       string
		personID string
		amount   float64
		paid     float64
	}
	var existing []existingShare
	for existingRows.Next() {
		var ex existingShare
		if err := existingRows.Scan(&ex.id, &ex.personID, &ex.amount, &ex.paid); err != nil {
			existingRows.Close()
			return fmt.Errorf("scan existing share: %w", err)
		}
		existing = append(existing, ex)
	}
	existingRows.Close()
	if err := existingRows.Err(); err != nil {
		return err
	}

	desired := make(map[string]models.ExpenseShareInput, len(shares))
	for _, sh := range shares {
		desired[sh.PersonID] = sh
	}

	for _, ex := range existing {
		sh, ok := desired[ex.personID]
		if !ok {
			if ex.paid > 0 {
				return fmt.Errorf("cannot remove share with payments")
			}
			if _, err := tx.Exec(ctx, "DELETE FROM expense_shares WHERE id=$1", ex.id); err != nil {
				return fmt.Errorf("delete share: %w", err)
			}
			continue
		}
		if sh.Amount < ex.paid {
			return fmt.Errorf("new amount below paid amount")
		}
		if _, err := tx.Exec(ctx,
			"UPDATE expense_shares SET amount=$1 WHERE id=$2", sh.Amount, ex.id); err != nil {
			return fmt.Errorf("update share: %w", err)
		}
		delete(desired, ex.personID)
	}

	for _, sh := range desired {
		if _, err := tx.Exec(ctx,
			`INSERT INTO expense_shares (expense_id, person_id, amount) VALUES ($1, $2, $3)`,
			expenseID, sh.PersonID, sh.Amount); err != nil {
			return fmt.Errorf("insert share: %w", err)
		}
	}

	return tx.Commit(ctx)
}

func (r *PostgresRepo) GetSharesByPerson(ctx context.Context, personID, userID, status string) ([]models.PersonShareExpense, error) {
	having := ""
	switch status {
	case "pending":
		having = " HAVING COALESCE(SUM(a.amount), 0) < s.amount"
	case "settled":
		having = " HAVING COALESCE(SUM(a.amount), 0) >= s.amount"
	}

	query := `SELECT s.id, s.expense_id, s.person_id, s.amount, COALESCE(SUM(a.amount), 0),
		e.id, e.user_id, e.category_id, e.card_id, e.amount, e.description, e.expense_date, e.source,
		COALESCE(e.receipt_url, ''), COALESCE(e.audio_url, ''), e.transaction_group_id, e.created_at,
		c.id, c.name, c.icon, c.color, COALESCE(c.type, 0), c.user_id,
		k.id, COALESCE(k.name, ''), COALESCE(k.franchise, ''), COALESCE(k.color, ''), COALESCE(k.cut_off_day, 1), COALESCE(k.payment_day, 1), k.credit_limit, COALESCE(k.created_at, '1970-01-01'::timestamptz)
	FROM expense_shares s
	JOIN expenses e ON s.expense_id = e.id
	JOIN people p ON s.person_id = p.id
	LEFT JOIN categories c ON e.category_id = c.id
	LEFT JOIN cards k ON e.card_id = k.id
	LEFT JOIN payment_allocations a ON a.share_id = s.id
	WHERE s.person_id=$1 AND p.user_id=$2
	GROUP BY s.id, e.id, c.id, k.id` + having + `
	ORDER BY e.expense_date DESC, e.created_at DESC`

	rows, err := r.pool.Query(ctx, query, personID, userID)
	if err != nil {
		return nil, fmt.Errorf("query shares by person: %w", err)
	}
	defer rows.Close()

	var result []models.PersonShareExpense
	for rows.Next() {
		var row models.PersonShareExpense
		row.Expense = models.Expense{Category: &models.Category{}}
		var paid float64
		var expenseID string
		var kID *string
		var cardName, cardFranchise, cardColor string
		var cardCutOff, cardPayment int
		var cardCredit *float64
		var cardCreated time.Time
		if err := rows.Scan(&row.Share.ID, &expenseID, &row.Share.PersonID, &row.Share.Amount, &paid,
			&row.Expense.ID, &row.Expense.UserID, &row.Expense.CategoryID, &row.Expense.CardID, &row.Expense.Amount, &row.Expense.Description, &row.Expense.ExpenseDate, &row.Expense.Source,
			&row.Expense.ReceiptURL, &row.Expense.AudioURL, &row.Expense.TransactionGroupID, &row.Expense.CreatedAt,
			&row.Expense.Category.ID, &row.Expense.Category.Name, &row.Expense.Category.Icon, &row.Expense.Category.Color, &row.Expense.Category.Type, &row.Expense.Category.UserID,
			&kID, &cardName, &cardFranchise, &cardColor, &cardCutOff, &cardPayment, &cardCredit, &cardCreated); err != nil {
			return nil, fmt.Errorf("scan share row: %w", err)
		}
		if kID != nil {
			row.Expense.Card = &models.Card{ID: *kID, UserID: userID, Name: cardName, Franchise: cardFranchise, Color: cardColor, CutOffDay: cardCutOff, PaymentDay: cardPayment, CreditLimit: cardCredit, CreatedAt: cardCreated}
		}
		row.Share.PaidAmount = paid
		row.Share.PendingAmount = row.Share.Amount - paid
		row.Share.Settled = paid >= row.Share.Amount
		result = append(result, row)
	}
	return result, rows.Err()
}

func (r *PostgresRepo) CreatePersonPayment(ctx context.Context, personID, userID string, amount float64, paidAt, note string) (*models.PersonPayment, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback(ctx)

	var owner string
	if err := tx.QueryRow(ctx, "SELECT user_id FROM people WHERE id=$1 AND user_id=$2 FOR UPDATE", personID, userID).Scan(&owner); err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("person not found")
		}
		return nil, fmt.Errorf("lock person: %w", err)
	}

	shareRows, err := tx.Query(ctx,
		`SELECT s.id, s.amount,
			COALESCE((SELECT SUM(a.amount) FROM payment_allocations a WHERE a.share_id = s.id), 0) AS paid
		FROM expense_shares s
		JOIN expenses e ON s.expense_id = e.id
		WHERE s.person_id=$1 AND e.user_id=$2
		ORDER BY e.expense_date ASC, s.created_at ASC
		FOR UPDATE OF s`, personID, userID)
	if err != nil {
		return nil, fmt.Errorf("query pending shares: %w", err)
	}

	type pendingShare struct {
		id     string
		amount float64
		paid   float64
	}
	var pending []pendingShare
	var totalPending float64
	for shareRows.Next() {
		var ps pendingShare
		if err := shareRows.Scan(&ps.id, &ps.amount, &ps.paid); err != nil {
			shareRows.Close()
			return nil, fmt.Errorf("scan pending share: %w", err)
		}
		if ps.paid >= ps.amount {
			continue
		}
		pending = append(pending, ps)
		totalPending += ps.amount - ps.paid
	}
	shareRows.Close()
	if err := shareRows.Err(); err != nil {
		return nil, err
	}

	if amount > totalPending {
		return nil, fmt.Errorf("payment exceeds pending amount")
	}

	payment := &models.PersonPayment{PersonID: personID, Amount: amount, PaidAt: paidAt, Note: note}
	if err := tx.QueryRow(ctx,
		`INSERT INTO person_payments (person_id, amount, paid_at, note) VALUES ($1, $2, $3, $4) RETURNING id, created_at`,
		personID, amount, paidAt, note,
	).Scan(&payment.ID, &payment.CreatedAt); err != nil {
		return nil, fmt.Errorf("insert payment: %w", err)
	}

	remaining := amount
	for _, ps := range pending {
		if remaining <= 0 {
			break
		}
		toApply := ps.amount - ps.paid
		if toApply > remaining {
			toApply = remaining
		}
		if _, err := tx.Exec(ctx,
			`INSERT INTO payment_allocations (payment_id, share_id, amount) VALUES ($1, $2, $3)`,
			payment.ID, ps.id, toApply); err != nil {
			return nil, fmt.Errorf("insert allocation: %w", err)
		}
		payment.Allocations = append(payment.Allocations, models.PaymentAllocation{
			PaymentID: payment.ID,
			ShareID:   ps.id,
			Amount:    toApply,
		})
		remaining -= toApply
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return payment, nil
}

func (r *PostgresRepo) DeletePersonPayment(ctx context.Context, id, userID string) error {
	cmd, err := r.pool.Exec(ctx,
		`DELETE FROM person_payments pay USING people p
		WHERE pay.id=$1 AND pay.person_id=p.id AND p.user_id=$2`, id, userID)
	if err != nil {
		return err
	}
	if cmd.RowsAffected() == 0 {
		return fmt.Errorf("payment not found")
	}
	return nil
}

func (r *PostgresRepo) ListPersonPayments(ctx context.Context, personID, userID string) ([]models.PersonPayment, error) {
	query := `SELECT p.id, p.person_id, p.amount, p.paid_at, p.note, p.created_at,
		a.id, a.payment_id, a.share_id, a.amount
	FROM person_payments p
	LEFT JOIN payment_allocations a ON a.payment_id = p.id
	WHERE p.person_id=$1 AND EXISTS (SELECT 1 FROM people pe WHERE pe.id=p.person_id AND pe.user_id=$2)
	ORDER BY p.paid_at DESC, p.created_at DESC, a.created_at ASC`

	rows, err := r.pool.Query(ctx, query, personID, userID)
	if err != nil {
		return nil, fmt.Errorf("query payments: %w", err)
	}
	defer rows.Close()

	byID := make(map[string]*models.PersonPayment)
	var order []string
	for rows.Next() {
		var p models.PersonPayment
		var aID *string
		var alloc models.PaymentAllocation
		if err := rows.Scan(&p.ID, &p.PersonID, &p.Amount, &p.PaidAt, &p.Note, &p.CreatedAt,
			&aID, &alloc.PaymentID, &alloc.ShareID, &alloc.Amount); err != nil {
			return nil, fmt.Errorf("scan payment: %w", err)
		}
		if _, ok := byID[p.ID]; !ok {
			byID[p.ID] = &p
			order = append(order, p.ID)
		}
		if aID != nil {
			alloc.ID = *aID
			byID[p.ID].Allocations = append(byID[p.ID].Allocations, alloc)
		}
	}

	payments := make([]models.PersonPayment, 0, len(order))
	for _, id := range order {
		payments = append(payments, *byID[id])
	}
	return payments, rows.Err()
}

func (r *PostgresRepo) GetSharedSummary(ctx context.Context, userID string) (*models.SharedSummary, error) {
	summary := &models.SharedSummary{}

	err := r.pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(s.amount - COALESCE(a.amount, 0)), 0)
		FROM expense_shares s
		JOIN expenses e ON s.expense_id = e.id
		JOIN people p ON s.person_id = p.id
		LEFT JOIN payment_allocations a ON a.share_id = s.id
		WHERE p.user_id=$1 AND p.archived = false`, userID,
	).Scan(&summary.PendingTotal)
	if err != nil {
		return nil, fmt.Errorf("pending total: %w", err)
	}

	rows, err := r.pool.Query(ctx,
		`SELECT p.id, p.user_id, p.name, p.color, p.icon, p.archived, p.created_at,
			COALESCE(SUM(s.amount), 0), COALESCE(SUM(COALESCE(a.amount, 0)), 0),
			COALESCE(SUM(s.amount - COALESCE(a.amount, 0)), 0),
			MAX(e.expense_date)
		FROM people p
		LEFT JOIN expense_shares s ON s.person_id = p.id
		LEFT JOIN expenses e ON s.expense_id = e.id
		LEFT JOIN payment_allocations a ON a.share_id = s.id
		WHERE p.user_id=$1 AND p.archived = false
		GROUP BY p.id, p.user_id, p.name, p.color, p.icon, p.archived, p.created_at
		ORDER BY COALESCE(SUM(s.amount - COALESCE(a.amount, 0)), 0) DESC, LOWER(p.name)`, userID)
	if err != nil {
		return nil, fmt.Errorf("people summary: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var ps models.SharedPersonSummary
		var last *time.Time
		if err := rows.Scan(&ps.Person.ID, &ps.Person.UserID, &ps.Person.Name, &ps.Person.Color, &ps.Person.Icon, &ps.Person.Archived, &ps.Person.CreatedAt,
			&ps.SharedTotal, &ps.PaidTotal, &ps.PendingTotal, &last); err != nil {
			return nil, fmt.Errorf("scan summary row: %w", err)
		}
		ps.LastActivity = last
		summary.People = append(summary.People, ps)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	summary.PeopleCount = len(summary.People)
	return summary, nil
}
