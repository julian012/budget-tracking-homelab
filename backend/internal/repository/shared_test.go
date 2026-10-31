package repository

import (
	"context"
	"testing"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
)

func createTestCategory(t *testing.T, repo *PostgresRepo, userID, name string) *models.Category {
	t.Helper()
	c := &models.Category{Name: name, Icon: "tag", Color: "#6B7280", UserID: userID}
	if err := repo.CreateCategory(context.Background(), c); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	return c
}

func createTestPerson(t *testing.T, repo *PostgresRepo, userID, name string) *models.Person {
	t.Helper()
	p := &models.Person{UserID: userID, Name: name, Color: "#EF4444", Icon: "user"}
	if err := repo.CreatePerson(context.Background(), p); err != nil {
		t.Fatalf("CreatePerson: %v", err)
	}
	return p
}

func createTestExpense(t *testing.T, repo *PostgresRepo, userID, categoryID string, amount float64) *models.Expense {
	t.Helper()
	e := &models.Expense{
		UserID:      userID,
		CategoryID:  categoryID,
		Amount:      amount,
		Description: "shared expense",
		ExpenseDate: time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC),
		Source:      "form",
	}
	if err := repo.Create(context.Background(), e); err != nil {
		t.Fatalf("Create expense: %v", err)
	}
	return e
}

func TestCreatePerson(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-person-uid", Email: "p@test.com", Name: "Person User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	p := createTestPerson(t, repo, user.ID, "Juan")
	if p.ID == "" {
		t.Fatal("expected person ID")
	}
	if p.Name != "Juan" {
		t.Errorf("expected name Juan, got %s", p.Name)
	}
}

func TestListPeopleExcludesArchived(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-people-uid", Email: "p2@test.com", Name: "People User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}

	active := createTestPerson(t, repo, user.ID, "Active")
	archived := createTestPerson(t, repo, user.ID, "Archived")
	if err := repo.ArchivePerson(ctx, archived.ID, user.ID, true); err != nil {
		t.Fatalf("ArchivePerson: %v", err)
	}

	people, err := repo.ListPeople(ctx, user.ID, false)
	if err != nil {
		t.Fatalf("ListPeople: %v", err)
	}
	if len(people) != 1 || people[0].ID != active.ID {
		t.Errorf("expected 1 active person, got %d", len(people))
	}

	all, err := repo.ListPeople(ctx, user.ID, true)
	if err != nil {
		t.Fatalf("ListPeople all: %v", err)
	}
	if len(all) != 2 {
		t.Errorf("expected 2 people including archived, got %d", len(all))
	}
}

func TestReplaceExpenseShares(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-share-uid", Email: "s@test.com", Name: "Share User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := createTestCategory(t, repo, user.ID, "services")
	person := createTestPerson(t, repo, user.ID, "Roomie")
	expense := createTestExpense(t, repo, user.ID, cat.ID, 50000)

	shares := []models.ExpenseShareInput{{PersonID: person.ID, Amount: 25000}}
	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, shares); err != nil {
		t.Fatalf("ReplaceExpenseShares: %v", err)
	}

	loaded, err := repo.GetExpenseByID(ctx, expense.ID, user.ID)
	if err != nil {
		t.Fatalf("GetExpenseByID: %v", err)
	}
	if len(loaded.Shares) != 1 {
		t.Fatalf("expected 1 share, got %d", len(loaded.Shares))
	}
	if loaded.Shares[0].Amount != 25000 {
		t.Errorf("expected share amount 25000, got %v", loaded.Shares[0].Amount)
	}
	if loaded.Shares[0].PendingAmount != 25000 {
		t.Errorf("expected pending 25000, got %v", loaded.Shares[0].PendingAmount)
	}
}

func TestCreatePersonPaymentFIFO(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-pay-uid", Email: "pay@test.com", Name: "Payment User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := createTestCategory(t, repo, user.ID, "services")
	person := createTestPerson(t, repo, user.ID, "Roomie")

	e1 := createTestExpense(t, repo, user.ID, cat.ID, 50000)
	e2 := createTestExpense(t, repo, user.ID, cat.ID, 30000)
	if err := repo.ReplaceExpenseShares(ctx, e1.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 25000}}); err != nil {
		t.Fatalf("shares e1: %v", err)
	}
	if err := repo.ReplaceExpenseShares(ctx, e2.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 15000}}); err != nil {
		t.Fatalf("shares e2: %v", err)
	}

	payment, err := repo.CreatePersonPayment(ctx, person.ID, user.ID, 35000, "2026-10-21", "partial")
	if err != nil {
		t.Fatalf("CreatePersonPayment: %v", err)
	}
	if payment.Amount != 35000 {
		t.Errorf("expected payment amount 35000, got %v", payment.Amount)
	}
	if len(payment.Allocations) != 2 {
		t.Errorf("expected 2 allocations, got %d", len(payment.Allocations))
	}

	summary, err := repo.GetSharedSummary(ctx, user.ID)
	if err != nil {
		t.Fatalf("GetSharedSummary: %v", err)
	}
	if summary.PendingTotal != 5000 {
		t.Errorf("expected pending total 5000, got %v", summary.PendingTotal)
	}
}

func TestDeleteExpenseBlockedWithPayments(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-del-exp-uid", Email: "de@test.com", Name: "Del User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := createTestCategory(t, repo, user.ID, "services")
	person := createTestPerson(t, repo, user.ID, "Roomie")
	expense := createTestExpense(t, repo, user.ID, cat.ID, 50000)
	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 25000}}); err != nil {
		t.Fatalf("shares: %v", err)
	}
	if _, err := repo.CreatePersonPayment(ctx, person.ID, user.ID, 25000, "2026-10-21", ""); err != nil {
		t.Fatalf("payment: %v", err)
	}

	count, err := repo.CountPaymentAllocationsForExpense(ctx, expense.ID, user.ID)
	if err != nil {
		t.Fatalf("CountPaymentAllocationsForExpense: %v", err)
	}
	if count != 1 {
		t.Errorf("expected 1 allocation, got %d", count)
	}

	// El bloqueo de borrado con pagos ocurre en la capa de servicio (ver
	// service/shared_test.go y handler/shared_test.go). El repositorio expone
	// el conteo para que la capa superior decida.
}

func TestReplaceExpenseSharesPreservesPayments(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-edit-uid", Email: "edit@test.com", Name: "Edit User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := createTestCategory(t, repo, user.ID, "services")
	person := createTestPerson(t, repo, user.ID, "Roomie")
	expense := createTestExpense(t, repo, user.ID, cat.ID, 50000)
	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 25000}}); err != nil {
		t.Fatalf("shares: %v", err)
	}
	if _, err := repo.CreatePersonPayment(ctx, person.ID, user.ID, 10000, "2026-10-21", ""); err != nil {
		t.Fatalf("payment: %v", err)
	}

	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 5000}}); err == nil {
		t.Error("expected error lowering share below paid amount")
	}

	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 30000}}); err != nil {
		t.Fatalf("update share above paid: %v", err)
	}
	loaded, _ := repo.GetExpenseByID(ctx, expense.ID, user.ID)
	if loaded.Shares[0].PendingAmount != 20000 {
		t.Errorf("expected pending 20000 after update, got %v", loaded.Shares[0].PendingAmount)
	}
}

func TestGetSharesByPersonStatus(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-status-uid", Email: "status@test.com", Name: "Status User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := createTestCategory(t, repo, user.ID, "services")
	person := createTestPerson(t, repo, user.ID, "Roomie")
	expense := createTestExpense(t, repo, user.ID, cat.ID, 50000)
	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 25000}}); err != nil {
		t.Fatalf("shares: %v", err)
	}

	pending, err := repo.GetSharesByPerson(ctx, person.ID, user.ID, "pending")
	if err != nil {
		t.Fatalf("GetSharesByPerson pending: %v", err)
	}
	if len(pending) != 1 {
		t.Errorf("expected 1 pending share, got %d", len(pending))
	}

	settled, err := repo.GetSharesByPerson(ctx, person.ID, user.ID, "settled")
	if err != nil {
		t.Fatalf("GetSharesByPerson settled: %v", err)
	}
	if len(settled) != 0 {
		t.Errorf("expected 0 settled shares, got %d", len(settled))
	}
}

func TestDeletePersonPayment(t *testing.T) {
	repo := getTestDB(t)
	ctx := context.Background()
	user := &models.User{FirebaseUID: "test-delpay-uid", Email: "delpay@test.com", Name: "DelPay User"}
	if err := repo.CreateUser(ctx, user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	cat := createTestCategory(t, repo, user.ID, "services")
	person := createTestPerson(t, repo, user.ID, "Roomie")
	expense := createTestExpense(t, repo, user.ID, cat.ID, 50000)
	if err := repo.ReplaceExpenseShares(ctx, expense.ID, user.ID, []models.ExpenseShareInput{{PersonID: person.ID, Amount: 25000}}); err != nil {
		t.Fatalf("shares: %v", err)
	}
	payment, err := repo.CreatePersonPayment(ctx, person.ID, user.ID, 10000, "2026-10-21", "")
	if err != nil {
		t.Fatalf("payment: %v", err)
	}

	if err := repo.DeletePersonPayment(ctx, payment.ID, user.ID); err != nil {
		t.Fatalf("DeletePersonPayment: %v", err)
	}

	loaded, _ := repo.GetExpenseByID(ctx, expense.ID, user.ID)
	if loaded.Shares[0].PendingAmount != 25000 {
		t.Errorf("expected pending restored to 25000, got %v", loaded.Shares[0].PendingAmount)
	}
}
