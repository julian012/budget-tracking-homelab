package handler

import (
	"encoding/json"
	"net/http"
	"testing"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
)

func TestCreateAndListPeople(t *testing.T) {
	router, repo := newTestRouter(t)
	user := createTestUser(t, repo, "people-handler")

	res := doJSON(t, router, "POST", "/api/people", user.ID, map[string]interface{}{"name": "Juan", "color": "#EF4444", "icon": "user"})
	if res.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", res.Code, res.Body.String())
	}
	var person models.Person
	if err := json.Unmarshal(res.Body.Bytes(), &person); err != nil {
		t.Fatalf("decode person: %v", err)
	}
	if person.Name != "Juan" {
		t.Errorf("expected Juan, got %s", person.Name)
	}

	list := doJSON(t, router, "GET", "/api/people", user.ID, nil)
	if list.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", list.Code)
	}
	var people []models.Person
	if err := json.Unmarshal(list.Body.Bytes(), &people); err != nil {
		t.Fatalf("decode people: %v", err)
	}
	if len(people) != 1 {
		t.Errorf("expected 1 person, got %d", len(people))
	}
}

func TestCreateSharedExpense(t *testing.T) {
	router, repo := newTestRouter(t)
	user := createTestUser(t, repo, "shared-exp-handler")
	cat := createTestCategory(t, repo, user.ID, "services")

	personRes := doJSON(t, router, "POST", "/api/people", user.ID, map[string]interface{}{"name": "Roomie"})
	var person models.Person
	json.Unmarshal(personRes.Body.Bytes(), &person)

	body := map[string]interface{}{
		"category_id":  cat.ID,
		"amount":       50000,
		"expense_date": "2026-10-20",
		"source":       "form",
		"shares": []map[string]interface{}{
			{"person_id": person.ID, "amount": 25000},
		},
	}
	res := doJSON(t, router, "POST", "/api/expenses", user.ID, body)
	if res.Code != http.StatusCreated {
		t.Fatalf("expected 201, got %d: %s", res.Code, res.Body.String())
	}
	var expense models.Expense
	if err := json.Unmarshal(res.Body.Bytes(), &expense); err != nil {
		t.Fatalf("decode expense: %v", err)
	}
	if len(expense.Shares) != 1 || expense.Shares[0].Amount != 25000 {
		t.Errorf("expected 1 share of 25000, got %+v", expense.Shares)
	}
}

func TestDeleteExpenseWithPaymentsBlockedHTTP(t *testing.T) {
	router, repo := newTestRouter(t)
	user := createTestUser(t, repo, "del-exp-handler")
	cat := createTestCategory(t, repo, user.ID, "services")

	personRes := doJSON(t, router, "POST", "/api/people", user.ID, map[string]interface{}{"name": "Roomie"})
	var person models.Person
	json.Unmarshal(personRes.Body.Bytes(), &person)

	expRes := doJSON(t, router, "POST", "/api/expenses", user.ID, map[string]interface{}{
		"category_id":  cat.ID,
		"amount":       50000,
		"expense_date": "2026-10-20",
		"source":       "form",
		"shares":       []map[string]interface{}{{"person_id": person.ID, "amount": 25000}},
	})
	var expense models.Expense
	json.Unmarshal(expRes.Body.Bytes(), &expense)

	payRes := doJSON(t, router, "POST", "/api/people/"+person.ID+"/payments", user.ID, map[string]interface{}{"amount": 25000, "paid_at": "2026-10-21"})
	if payRes.Code != http.StatusCreated {
		t.Fatalf("expected payment 201, got %d: %s", payRes.Code, payRes.Body.String())
	}

	delRes := doJSON(t, router, "DELETE", "/api/expenses/"+expense.ID, user.ID, nil)
	if delRes.Code != http.StatusConflict {
		t.Errorf("expected 409 deleting expense with payments, got %d", delRes.Code)
	}
}

func TestCreatePaymentExceedsPending(t *testing.T) {
	router, repo := newTestRouter(t)
	user := createTestUser(t, repo, "pay-exceeds-handler")
	cat := createTestCategory(t, repo, user.ID, "services")

	personRes := doJSON(t, router, "POST", "/api/people", user.ID, map[string]interface{}{"name": "Roomie"})
	var person models.Person
	json.Unmarshal(personRes.Body.Bytes(), &person)

	doJSON(t, router, "POST", "/api/expenses", user.ID, map[string]interface{}{
		"category_id":  cat.ID,
		"amount":       50000,
		"expense_date": "2026-10-20",
		"source":       "form",
		"shares":       []map[string]interface{}{{"person_id": person.ID, "amount": 25000}},
	})

	res := doJSON(t, router, "POST", "/api/people/"+person.ID+"/payments", user.ID, map[string]interface{}{"amount": 30000, "paid_at": "2026-10-21"})
	if res.Code != http.StatusConflict {
		t.Errorf("expected 409 for payment exceeding pending, got %d", res.Code)
	}
}

func TestGetSharedSummary(t *testing.T) {
	router, repo := newTestRouter(t)
	user := createTestUser(t, repo, "summary-handler")
	cat := createTestCategory(t, repo, user.ID, "services")

	personRes := doJSON(t, router, "POST", "/api/people", user.ID, map[string]interface{}{"name": "Roomie"})
	var person models.Person
	json.Unmarshal(personRes.Body.Bytes(), &person)

	doJSON(t, router, "POST", "/api/expenses", user.ID, map[string]interface{}{
		"category_id":  cat.ID,
		"amount":       50000,
		"expense_date": "2026-10-20",
		"source":       "form",
		"shares":       []map[string]interface{}{{"person_id": person.ID, "amount": 25000}},
	})

	res := doJSON(t, router, "GET", "/api/shared/summary", user.ID, nil)
	if res.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", res.Code, res.Body.String())
	}
	var summary models.SharedSummary
	if err := json.Unmarshal(res.Body.Bytes(), &summary); err != nil {
		t.Fatalf("decode summary: %v", err)
	}
	if summary.PendingTotal != 25000 {
		t.Errorf("expected pending 25000, got %v", summary.PendingTotal)
	}
	if summary.PeopleCount != 1 {
		t.Errorf("expected 1 person, got %d", summary.PeopleCount)
	}
}
