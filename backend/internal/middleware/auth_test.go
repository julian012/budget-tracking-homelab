package middleware

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
)

type fakeUserRepo struct {
	getErr    error
	createErr error
	created   bool
}

func (f *fakeUserRepo) GetUserByFirebaseUID(ctx context.Context, uid string) (*models.User, error) {
	if f.getErr != nil {
		return nil, f.getErr
	}
	return &models.User{ID: "existing-id", FirebaseUID: uid}, nil
}

func (f *fakeUserRepo) CreateUser(ctx context.Context, user *models.User) error {
	f.created = true
	if f.createErr != nil {
		return f.createErr
	}
	user.ID = "new-id"
	return nil
}

func TestVerifyToken_FailsClosedWithoutDevAuth(t *testing.T) {
	a := NewFirebaseAuth("", false, &fakeUserRepo{})
	if _, err := a.verifyToken(context.Background(), "any-token"); err == nil {
		t.Fatal("esperaba error cuando falta FIREBASE_WEB_API_KEY y ALLOW_DEV_AUTH=false")
	}
}

func TestVerifyToken_AllowsDevAuthWhenExplicit(t *testing.T) {
	a := NewFirebaseAuth("", true, &fakeUserRepo{})
	uid, err := a.verifyToken(context.Background(), "any-token")
	if err != nil {
		t.Fatalf("no esperaba error: %v", err)
	}
	if uid != "dev-user-id" {
		t.Fatalf("uid = %q, want %q", uid, "dev-user-id")
	}
}

func TestAuthenticate_AbortsWhenCreateUserFails(t *testing.T) {
	repo := &fakeUserRepo{getErr: errors.New("not found"), createErr: errors.New("db down")}
	a := NewFirebaseAuth("", true, repo)

	nextCalled := false
	handler := a.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nextCalled = true
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer any-token")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if nextCalled {
		t.Fatal("no debería llamar al siguiente handler si CreateUser falla")
	}
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusInternalServerError)
	}
	if !repo.created {
		t.Fatal("esperaba que se intentara CreateUser")
	}
}

func TestAuthenticate_SetsUserIDWhenCreateUserSucceeds(t *testing.T) {
	repo := &fakeUserRepo{getErr: errors.New("not found")}
	a := NewFirebaseAuth("", true, repo)

	var gotUserID string
	handler := a.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotUserID = GetUserID(r)
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	req.Header.Set("Authorization", "Bearer any-token")
	rec := httptest.NewRecorder()

	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}
	if gotUserID != "new-id" {
		t.Fatalf("userID = %q, want %q", gotUserID, "new-id")
	}
}

func TestAuthenticate_RejectsMissingAuthHeader(t *testing.T) {
	a := NewFirebaseAuth("", true, &fakeUserRepo{})
	handler := a.Authenticate(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("no debería llamar al siguiente handler sin Authorization header")
	}))

	req := httptest.NewRequest(http.MethodGet, "/", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusUnauthorized)
	}
}
