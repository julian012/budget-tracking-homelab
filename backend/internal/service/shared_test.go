package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
	"github.com/example/budget-tracking-homelab/backend/internal/repository"
)

type sharedFakeRepo struct {
	repository.ExpenseRepo
	people        map[string]*models.Person
	createdPerson *models.Person
	savedExpense  *models.Expense
	shares        []models.ExpenseShareInput
	payment       *models.PersonPayment
	allocations   int
}

func (f *sharedFakeRepo) GetCategoryByID(ctx context.Context, id, userID string) (*models.Category, error) {
	return &models.Category{ID: id, UserID: userID}, nil
}

func (f *sharedFakeRepo) GetCardByID(ctx context.Context, id, userID string) (*models.Card, error) {
	return &models.Card{ID: id, UserID: userID}, nil
}

func (f *sharedFakeRepo) Create(ctx context.Context, expense *models.Expense) error {
	expense.ID = "exp-1"
	expense.CreatedAt = time.Now()
	f.savedExpense = expense
	return nil
}

func (f *sharedFakeRepo) GetExpenseByID(ctx context.Context, id, userID string) (*models.Expense, error) {
	if f.savedExpense == nil {
		return nil, nil
	}
	e := *f.savedExpense
	e.Shares = []models.ExpenseShare{
		{ID: "sh-1", PersonID: "p-1", Amount: 25000, PaidAmount: 0, PendingAmount: 25000, Settled: false},
	}
	return &e, nil
}

func (f *sharedFakeRepo) UpdateExpense(ctx context.Context, expense *models.Expense) error {
	f.savedExpense = expense
	return nil
}

func (f *sharedFakeRepo) GetPersonByID(ctx context.Context, id, userID string) (*models.Person, error) {
	p, ok := f.people[id]
	if !ok {
		return nil, errors.New("person not found")
	}
	return p, nil
}

func (f *sharedFakeRepo) ReplaceExpenseShares(ctx context.Context, expenseID, userID string, shares []models.ExpenseShareInput) error {
	f.shares = shares
	return nil
}

func (f *sharedFakeRepo) CountPaymentAllocationsForExpense(ctx context.Context, expenseID, userID string) (int, error) {
	return f.allocations, nil
}

func (f *sharedFakeRepo) CreatePersonPayment(ctx context.Context, personID, userID string, amount float64, paidAt, note string) (*models.PersonPayment, error) {
	f.payment = &models.PersonPayment{PersonID: personID, Amount: amount, PaidAt: paidAt, Note: note}
	return f.payment, nil
}

func (f *sharedFakeRepo) CreatePerson(ctx context.Context, person *models.Person) error {
	person.ID = "p-new"
	f.createdPerson = person
	return nil
}

func newSharedFakeRepo() *sharedFakeRepo {
	return &sharedFakeRepo{
		people: map[string]*models.Person{
			"p-1": {ID: "p-1", UserID: "u-1", Name: "Juan"},
		},
	}
}

func TestCreateExpenseWithSharesValidation(t *testing.T) {
	svc := NewExpenseService(newSharedFakeRepo(), nil, "", "")
	ctx := context.Background()

	valid := models.ExpenseInput{
		CategoryID:  "c-1",
		Amount:      50000,
		ExpenseDate: "2026-10-20",
		Source:      "form",
		Shares:      []models.ExpenseShareInput{{PersonID: "p-1", Amount: 25000}},
	}
	_, err := svc.CreateExpense(ctx, "u-1", valid)
	if err != nil {
		t.Fatalf("expected valid shares to pass, got %v", err)
	}

	group := "group-1"
	invalid := valid
	invalid.TransactionGroupID = &group
	_, err = svc.CreateExpense(ctx, "u-1", invalid)
	if err == nil {
		t.Error("expected error when shares combined with transaction group")
	}

	exceeds := valid
	exceeds.Shares = []models.ExpenseShareInput{{PersonID: "p-1", Amount: 60000}}
	_, err = svc.CreateExpense(ctx, "u-1", exceeds)
	if err == nil {
		t.Error("expected error when shares exceed amount")
	}

	dup := valid
	dup.Shares = []models.ExpenseShareInput{
		{PersonID: "p-1", Amount: 10000},
		{PersonID: "p-1", Amount: 15000},
	}
	_, err = svc.CreateExpense(ctx, "u-1", dup)
	if err == nil {
		t.Error("expected error for duplicate person in shares")
	}
}

func TestDeleteExpenseWithPaymentsBlocked(t *testing.T) {
	repo := newSharedFakeRepo()
	repo.allocations = 1
	svc := NewExpenseService(repo, nil, "", "")
	ctx := context.Background()

	if err := svc.DeleteExpense(ctx, "exp-1", "u-1"); err == nil {
		t.Error("expected error deleting expense with payments")
	}
}

func TestCreatePersonValidation(t *testing.T) {
	svc := NewExpenseService(newSharedFakeRepo(), nil, "", "")
	ctx := context.Background()

	_, err := svc.CreatePerson(ctx, "u-1", models.PersonInput{Name: "  "})
	if err == nil {
		t.Error("expected error for empty person name")
	}

	p, err := svc.CreatePerson(ctx, "u-1", models.PersonInput{Name: "Pedro"})
	if err != nil {
		t.Fatalf("expected person creation, got %v", err)
	}
	if p.Name != "Pedro" {
		t.Errorf("expected name Pedro, got %s", p.Name)
	}
}

func TestCreatePersonPaymentValidation(t *testing.T) {
	svc := NewExpenseService(newSharedFakeRepo(), nil, "", "")
	ctx := context.Background()

	_, err := svc.CreatePersonPayment(ctx, "u-1", "p-1", 0, "2026-10-21", "")
	if err == nil {
		t.Error("expected error for zero amount payment")
	}

	_, err = svc.CreatePersonPayment(ctx, "u-1", "p-1", 1000, "bad-date", "")
	if err == nil {
		t.Error("expected error for invalid date")
	}
}
