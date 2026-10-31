package repository

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
)

func getTestDB(t *testing.T) *PostgresRepo {
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Fatal("TEST_DATABASE_URL es obligatoria; los tests NUNCA deben apuntar a la base de producción")
	}
	if !strings.Contains(dsn, "budget_test") {
		t.Fatalf("TEST_DATABASE_URL debe apuntar a budget_test, se obtuvo: %s", dsn)
	}

	repo, err := NewPostgresRepo(dsn)
	if err != nil {
		t.Fatalf("connect to test db: %v", err)
	}

	t.Cleanup(func() {
		repo.pool.Exec(context.Background(), "TRUNCATE payment_allocations, person_payments, expense_shares, expenses, presets, categories, cards, users RESTART IDENTITY CASCADE")
	})

	return repo
}

func ptr[T any](v T) *T { return &v }

func TestCreateUser(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{
		FirebaseUID: "test-uid-123",
		Email:       "test@example.com",
		Name:        "Test User",
	}

	err := repo.CreateUser(ctx, user)
	if err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	if user.ID == "" {
		t.Error("expected user ID to be set")
	}

	found, err := repo.GetUserByFirebaseUID(ctx, "test-uid-123")
	if err != nil {
		t.Fatalf("GetUserByFirebaseUID: %v", err)
	}
	if found.Email != "test@example.com" {
		t.Errorf("expected email test@example.com, got %s", found.Email)
	}
}

func TestCreateCategory(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-cat", Email: "cat@test.com", Name: "Cat User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	cat := &models.Category{
		Name:          "alimentos",
		Icon:          "utensils",
		Color:         "#EF4444",
		Type:          1,
		DefaultAmount: 8500,
		UserID:        user.ID,
	}
	if err := repo.CreateCategory(ctx, cat); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	if cat.ID == "" {
		t.Error("expected category ID to be set")
	}

	categories, err := repo.GetCategories(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetCategories: %v", err)
	}
	if len(categories) != 1 {
		t.Errorf("expected 1 category, got %d", len(categories))
	}
	if categories[0].DefaultAmount != 8500 {
		t.Errorf("expected DefaultAmount=8500, got %v", categories[0].DefaultAmount)
	}
	if categories[0].Type != 1 {
		t.Errorf("expected Type=1 (fixed), got %d", categories[0].Type)
	}
}

func TestGetCategoryByID(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	owner := &models.User{FirebaseUID: "test-uid-owner", Email: "owner@test.com", Name: "Owner"}
	if err := repo.CreateUser(ctx, owner); err != nil {
		t.Fatalf("CreateUser owner: %v", err)
	}
	other := &models.User{FirebaseUID: "test-uid-other", Email: "other@test.com", Name: "Other"}
	if err := repo.CreateUser(ctx, other); err != nil {
		t.Fatalf("CreateUser other: %v", err)
	}

	cat := &models.Category{Name: "transporte", Icon: "bus", Color: "#0F52BA", UserID: owner.ID}
	if err := repo.CreateCategory(ctx, cat); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}

	got, err := repo.GetCategoryByID(ctx, cat.ID, owner.ID)
	if err != nil {
		t.Fatalf("GetCategoryByID(owner): %v", err)
	}
	if got.ID != cat.ID {
		t.Errorf("expected category %s, got %s", cat.ID, got.ID)
	}

	if _, err := repo.GetCategoryByID(ctx, cat.ID, other.ID); err == nil {
		t.Error("expected error fetching another user's category, got nil")
	}
}

func TestUpdateCategoryDefaultAmount(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-cat-default", Email: "catdefault@test.com", Name: "Cat Default User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	cat := &models.Category{Name: "comida", Icon: "utensils", Color: "#EF4444", UserID: user.ID}
	if err := repo.CreateCategory(ctx, cat); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}

	cat.DefaultAmount = 9000
	if err := repo.UpdateCategory(ctx, cat); err != nil {
		t.Fatalf("UpdateCategory: %v", err)
	}

	categories, err := repo.GetCategories(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetCategories: %v", err)
	}
	if len(categories) != 1 {
		t.Fatalf("expected 1 category, got %d", len(categories))
	}
	if categories[0].DefaultAmount != 9000 {
		t.Errorf("expected DefaultAmount=9000 after update, got %v", categories[0].DefaultAmount)
	}
}

func TestGetCategoriesOrdered(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-cat-order", Email: "order@test.com", Name: "Order User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	names := []string{"transporte", "alimentos", "hogar", "Ropa", "salud"}
	for _, name := range names {
		cat := &models.Category{Name: name, Icon: "tag", Color: "#EF4444", UserID: user.ID}
		if err := repo.CreateCategory(ctx, cat); err != nil {
			t.Fatalf("CreateCategory %s: %v", name, err)
		}
	}

	categories, err := repo.GetCategories(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetCategories: %v", err)
	}
	if len(categories) != len(names) {
		t.Fatalf("expected %d categories, got %d", len(names), len(categories))
	}

	expected := []string{"alimentos", "hogar", "Ropa", "salud", "transporte"}
	for i, want := range expected {
		if categories[i].Name != want {
			t.Errorf("position %d: expected %q, got %q", i, want, categories[i].Name)
		}
	}
}

func TestPresetCRUD(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-preset", Email: "preset@test.com", Name: "Preset User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := &models.Category{Name: "transporte", Icon: "bus", Color: "#0F52BA", UserID: user.ID}
	if err := repo.CreateCategory(ctx, cat); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	card := &models.Card{UserID: user.ID, Name: "Visa", Franchise: "visa", Color: "#FFFFFF", CutOffDay: 5, PaymentDay: 10}
	if err := repo.CreateCard(ctx, card); err != nil {
		t.Fatalf("CreateCard: %v", err)
	}

	preset := &models.Preset{
		UserID: user.ID, Name: "Flota Tunja-Bogotá", Icon: "🚌", Amount: 25000,
		CategoryID: cat.ID, CardID: &card.ID, Description: "pasajes",
	}
	if err := repo.CreatePreset(ctx, preset); err != nil {
		t.Fatalf("CreatePreset: %v", err)
	}
	if preset.ID == "" {
		t.Fatal("expected preset ID to be set")
	}

	got, err := repo.GetPresetByID(ctx, preset.ID, user.ID)
	if err != nil {
		t.Fatalf("GetPresetByID: %v", err)
	}
	if got.Amount != 25000 || got.CategoryID != cat.ID {
		t.Errorf("preset no round-tripea: %+v", got)
	}
	if got.CardID == nil || *got.CardID != card.ID {
		t.Errorf("CardID = %v, want %q", got.CardID, card.ID)
	}

	other := &models.User{FirebaseUID: "test-uid-preset-other", Email: "other@test.com", Name: "Other"}
	if err := repo.CreateUser(ctx, other); err != nil {
		t.Fatalf("CreateUser other: %v", err)
	}
	if _, err := repo.GetPresetByID(ctx, preset.ID, other.ID); err == nil {
		t.Error("expected error fetching another user's preset, got nil")
	}

	preset.Name = "Flota actualizada"
	preset.Amount = 27000
	preset.CategoryID = ""
	preset.CardID = nil
	if err := repo.UpdatePreset(ctx, preset); err != nil {
		t.Fatalf("UpdatePreset: %v", err)
	}
	list, err := repo.GetPresets(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetPresets: %v", err)
	}
	if len(list) != 1 {
		t.Fatalf("expected 1 preset, got %d", len(list))
	}
	if list[0].Name != "Flota actualizada" || list[0].Amount != 27000 {
		t.Errorf("preset no actualizado: %+v", list[0])
	}
	if list[0].CategoryID != "" {
		t.Errorf("CategoryID = %q, want vacío tras limpiarlo", list[0].CategoryID)
	}

	if err := repo.DeletePreset(ctx, preset.ID, user.ID); err != nil {
		t.Fatalf("DeletePreset: %v", err)
	}
	list, _ = repo.GetPresets(ctx, user.ID)
	if len(list) != 0 {
		t.Errorf("expected 0 presets after delete, got %d", len(list))
	}
}

func TestCreateExpense(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-exp", Email: "exp@test.com", Name: "Exp User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	cat := &models.Category{Name: "transporte", Icon: "car", Color: "#F59E0B", UserID: user.ID}
	if err := repo.CreateCategory(ctx, cat); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}

	expense := &models.Expense{
		UserID:             user.ID,
		CategoryID:         cat.ID,
		Amount:             25.50,
		Description:        "Bus pass",
		ExpenseDate:        time.Now(),
		Source:             "form",
		TransactionGroupID: ptr("11111111-2222-3333-4444-555555555555"),
	}

	if err := repo.Create(ctx, expense); err != nil {
		t.Fatalf("Create expense: %v", err)
	}
	if expense.ID == "" {
		t.Error("expected expense ID to be set")
	}

	expenses, err := repo.GetExpenses(ctx, user.ID, time.Time{}, time.Time{}, "")
	if err != nil {
		t.Fatalf("GetExpenses: %v", err)
	}
	if len(expenses) != 1 {
		t.Errorf("expected 1 expense, got %d", len(expenses))
	}
	if expenses[0].Amount != 25.50 {
		t.Errorf("expected amount 25.50, got %f", expenses[0].Amount)
	}
	if expenses[0].TransactionGroupID == nil || *expenses[0].TransactionGroupID != "11111111-2222-3333-4444-555555555555" {
		t.Errorf("expected transaction_group_id to round-trip, got %v", expenses[0].TransactionGroupID)
	}
}

func TestGetExpenseByID(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-get", Email: "get@test.com", Name: "Get User"}
	repo.CreateUser(ctx, user)
	cat := &models.Category{Name: "hogar", Icon: "home", Color: "#EC4899", UserID: user.ID}
	repo.CreateCategory(ctx, cat)

	expense := &models.Expense{UserID: user.ID, CategoryID: cat.ID, Amount: 100, Description: "Rent", ExpenseDate: time.Now(), Source: "form"}
	repo.Create(ctx, expense)

	found, err := repo.GetExpenseByID(ctx, expense.ID, user.ID)
	if err != nil {
		t.Fatalf("GetExpenseByID: %v", err)
	}
	if found.Description != "Rent" {
		t.Errorf("expected Rent, got %s", found.Description)
	}
}

func TestUpdateExpense(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-upd", Email: "upd@test.com", Name: "Upd User"}
	repo.CreateUser(ctx, user)
	cat := &models.Category{Name: "ropa", Icon: "shirt", Color: "#14B8A6", UserID: user.ID}
	repo.CreateCategory(ctx, cat)

	expense := &models.Expense{UserID: user.ID, CategoryID: cat.ID, Amount: 50, Description: "Old", ExpenseDate: time.Now(), Source: "form"}
	repo.Create(ctx, expense)

	expense.Description = "Updated"
	if err := repo.UpdateExpense(ctx, expense); err != nil {
		t.Fatalf("UpdateExpense: %v", err)
	}

	found, _ := repo.GetExpenseByID(ctx, expense.ID, user.ID)
	if found.Description != "Updated" {
		t.Errorf("expected Updated, got %s", found.Description)
	}
}

func TestDeleteExpense(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-del", Email: "del@test.com", Name: "Del User"}
	repo.CreateUser(ctx, user)
	cat := &models.Category{Name: "salud", Icon: "heart", Color: "#10B981", UserID: user.ID}
	repo.CreateCategory(ctx, cat)

	expense := &models.Expense{UserID: user.ID, CategoryID: cat.ID, Amount: 30, Description: "Medicine", ExpenseDate: time.Now(), Source: "form"}
	repo.Create(ctx, expense)

	if err := repo.DeleteExpense(ctx, expense.ID, user.ID); err != nil {
		t.Fatalf("DeleteExpense: %v", err)
	}

	_, err := repo.GetExpenseByID(ctx, expense.ID, user.ID)
	if err == nil {
		t.Error("expected expense to be deleted")
	}
}

func TestGetStats(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-stats", Email: "stats@test.com", Name: "Stats User"}
	repo.CreateUser(ctx, user)
	cat := &models.Category{Name: "educacion", Icon: "book", Color: "#6366F1", UserID: user.ID}
	repo.CreateCategory(ctx, cat)

	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: cat.ID, Amount: 200, Description: "Course", ExpenseDate: time.Now(), Source: "form"})

	card := &models.Card{UserID: user.ID, Name: "Visa", Franchise: "visa", Color: "#FFFFFF", CutOffDay: 5, PaymentDay: 10}
	repo.CreateCard(ctx, card)
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: cat.ID, Amount: 150, Description: "Books", ExpenseDate: time.Now(), Source: "form", CardID: &card.ID})

	stats, err := repo.GetStats(ctx, user.ID, time.Time{}, time.Time{}, "")
	if err != nil {
		t.Fatalf("GetStats: %v", err)
	}
	if len(stats.ByCategory) == 0 {
		t.Error("expected at least 1 category in stats")
	}
	if stats.CashCount != 1 {
		t.Errorf("expected CashCount=1, got %d", stats.CashCount)
	}
	if stats.CardCount != 1 {
		t.Errorf("expected CardCount=1, got %d", stats.CardCount)
	}
}

func TestGetStatsOrdering(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-stats-order", Email: "stats-order@test.com", Name: "Stats Order User"}
	repo.CreateUser(ctx, user)

	catA := &models.Category{Name: "comida", Icon: "utensils", Color: "#FF0000", UserID: user.ID}
	catB := &models.Category{Name: "transporte", Icon: "car", Color: "#00FF00", UserID: user.ID}
	catC := &models.Category{Name: "salud", Icon: "heart", Color: "#0000FF", UserID: user.ID}
	repo.CreateCategory(ctx, catA)
	repo.CreateCategory(ctx, catB)
	repo.CreateCategory(ctx, catC)

	cardV := &models.Card{UserID: user.ID, Name: "Visa", Franchise: "visa", Color: "#FFFFFF", CutOffDay: 5, PaymentDay: 10}
	cardM := &models.Card{UserID: user.ID, Name: "Master", Franchise: "mastercard", Color: "#000000", CutOffDay: 5, PaymentDay: 10}
	repo.CreateCard(ctx, cardV)
	repo.CreateCard(ctx, cardM)

	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: catA.ID, Amount: 100, Description: "a", ExpenseDate: time.Now(), Source: "form"})
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: catB.ID, Amount: 300, Description: "b", ExpenseDate: time.Now(), Source: "form"})
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: catC.ID, Amount: 200, Description: "c", ExpenseDate: time.Now(), Source: "form"})
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: catA.ID, Amount: 100, Description: "v", ExpenseDate: time.Now(), Source: "form", CardID: &cardV.ID})
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: catC.ID, Amount: 200, Description: "m", ExpenseDate: time.Now(), Source: "form", CardID: &cardM.ID})
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: catB.ID, Amount: 300, Description: "cash", ExpenseDate: time.Now(), Source: "form"})

	stats, err := repo.GetStats(ctx, user.ID, time.Time{}, time.Time{}, "")
	if err != nil {
		t.Fatalf("GetStats: %v", err)
	}

	expectedCat := []string{"transporte", "salud", "comida"}
	if len(stats.ByCategory) != len(expectedCat) {
		t.Fatalf("expected %d categories, got %d", len(expectedCat), len(stats.ByCategory))
	}
	for i, name := range expectedCat {
		if stats.ByCategory[i].CategoryName != name {
			t.Errorf("by_category[%d] = %s, expected %s", i, stats.ByCategory[i].CategoryName, name)
		}
	}
	for i := 0; i < len(stats.ByCategory)-1; i++ {
		if stats.ByCategory[i].Total < stats.ByCategory[i+1].Total {
			t.Errorf("by_category not sorted desc: [%d]=%v < [%d]=%v", i, stats.ByCategory[i].Total, i+1, stats.ByCategory[i+1].Total)
		}
	}

	expectedPay := []string{"Efectivo", "Master", "Visa"}
	if len(stats.ByPayment) != len(expectedPay) {
		t.Fatalf("expected %d payment groups, got %d", len(expectedPay), len(stats.ByPayment))
	}
	for i, name := range expectedPay {
		if stats.ByPayment[i].Name != name {
			t.Errorf("by_payment[%d] = %s, expected %s", i, stats.ByPayment[i].Name, name)
		}
	}
	for i := 0; i < len(stats.ByPayment)-1; i++ {
		if stats.ByPayment[i].Total < stats.ByPayment[i+1].Total {
			t.Errorf("by_payment not sorted desc: [%d]=%v < [%d]=%v", i, stats.ByPayment[i].Total, i+1, stats.ByPayment[i+1].Total)
		}
	}
}

func TestGetStatsByType(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()

	user := &models.User{FirebaseUID: "test-uid-stats-type", Email: "statstype@test.com", Name: "Stats Type User"}
	repo.CreateUser(ctx, user)

	fixed := &models.Category{Name: "hogar", Icon: "home", Color: "#10B981", Type: 1, UserID: user.ID}
	variable := &models.Category{Name: "comida", Icon: "utensils", Color: "#EF4444", Type: 0, UserID: user.ID}
	repo.CreateCategory(ctx, fixed)
	repo.CreateCategory(ctx, variable)

	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: fixed.ID, Amount: 300, Description: "renta", ExpenseDate: time.Now(), Source: "form"})
	repo.Create(ctx, &models.Expense{UserID: user.ID, CategoryID: variable.ID, Amount: 100, Description: "almuerzo", ExpenseDate: time.Now(), Source: "form"})

	fixedStats, err := repo.GetStats(ctx, user.ID, time.Time{}, time.Time{}, "fixed")
	if err != nil {
		t.Fatalf("GetStats fixed: %v", err)
	}
	if len(fixedStats.ByCategory) != 1 {
		t.Fatalf("expected 1 fixed category, got %d", len(fixedStats.ByCategory))
	}
	if fixedStats.ByCategory[0].CategoryName != "hogar" {
		t.Errorf("expected hogar, got %s", fixedStats.ByCategory[0].CategoryName)
	}

	varStats, err := repo.GetStats(ctx, user.ID, time.Time{}, time.Time{}, "variable")
	if err != nil {
		t.Fatalf("GetStats variable: %v", err)
	}
	if len(varStats.ByCategory) != 1 {
		t.Fatalf("expected 1 variable category, got %d", len(varStats.ByCategory))
	}
	if varStats.ByCategory[0].CategoryName != "comida" {
		t.Errorf("expected comida, got %s", varStats.ByCategory[0].CategoryName)
	}

	allStats, err := repo.GetStats(ctx, user.ID, time.Time{}, time.Time{}, "")
	if err != nil {
		t.Fatalf("GetStats all: %v", err)
	}
	if len(allStats.ByCategory) != 2 {
		t.Errorf("expected 2 categories with no type filter, got %d", len(allStats.ByCategory))
	}
}
