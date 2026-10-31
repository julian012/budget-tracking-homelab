package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/example/budget-tracking-homelab/backend/internal/middleware"
	"github.com/example/budget-tracking-homelab/backend/internal/models"
	"github.com/example/budget-tracking-homelab/backend/internal/repository"
	"github.com/example/budget-tracking-homelab/backend/internal/service"
)

// newTestRouter monta el router real (RegisterRoutes) sobre un servicio real
// conectado a budget_test — estos son tests de integración de contrato HTTP,
// no unitarios: no hay mock de repository/service, solo se evita la capa de
// auth real (el userID se inyecta directo en el contexto, como haría
// middleware.Authenticate ya verificado).
func newTestRouter(t *testing.T) (*chi.Mux, *repository.PostgresRepo) {
	t.Helper()
	dsn := os.Getenv("TEST_DATABASE_URL")
	if dsn == "" {
		t.Fatal("TEST_DATABASE_URL es obligatoria; los tests NUNCA deben apuntar a la base de producción")
	}
	if !strings.Contains(dsn, "budget_test") {
		t.Fatalf("TEST_DATABASE_URL debe apuntar a budget_test, se obtuvo: %s", dsn)
	}

	repo, err := repository.NewPostgresRepo(dsn)
	if err != nil {
		t.Fatalf("connect to test db: %v", err)
	}
	t.Cleanup(func() {
		repo.Pool().Exec(context.Background(), "TRUNCATE payment_allocations, person_payments, expense_shares, expenses, presets, categories, cards, users RESTART IDENTITY CASCADE")
		repo.Close()
	})

	svc := service.NewExpenseService(repo, nil, "", "")
	h := NewExpenseHandler(svc)
	r := chi.NewRouter()
	h.RegisterRoutes(r)
	return r, repo
}

func createTestUser(t *testing.T, repo *repository.PostgresRepo, uid string) *models.User {
	t.Helper()
	user := &models.User{FirebaseUID: uid, Email: uid + "@test.com", Name: "Test User"}
	if err := repo.CreateUser(context.Background(), user); err != nil {
		t.Fatalf("CreateUser: %v", err)
	}
	return user
}

func createTestCategory(t *testing.T, repo *repository.PostgresRepo, userID, name string) *models.Category {
	t.Helper()
	cat := &models.Category{Name: name, Icon: "tag", Color: "#6B7280", UserID: userID}
	if err := repo.CreateCategory(context.Background(), cat); err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	return cat
}

func withUser(req *http.Request, userID string) *http.Request {
	return req.WithContext(context.WithValue(req.Context(), middleware.UserIDKey, userID))
}

func doJSON(t *testing.T, r *chi.Mux, method, path, userID string, body interface{}) *httptest.ResponseRecorder {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatalf("encode body: %v", err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if userID != "" {
		req = withUser(req, userID)
	}
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec
}

func TestCreateAndGetExpense(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")
	cat := createTestCategory(t, repo, user.ID, "comida")

	rec := doJSON(t, r, http.MethodPost, "/api/expenses", user.ID, models.ExpenseInput{
		CategoryID:  cat.ID,
		Amount:      15000,
		Description: "almuerzo",
		ExpenseDate: "2026-08-25",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST /expenses status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var created models.Expense
	if err := json.NewDecoder(rec.Body).Decode(&created); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if created.ID == "" {
		t.Fatal("esperaba un ID asignado")
	}

	rec = doJSON(t, r, http.MethodGet, "/api/expenses/"+created.ID, user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /expenses/{id} status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestCreateExpense_RejectsCategoryFromAnotherUser(t *testing.T) {
	r, repo := newTestRouter(t)
	owner := createTestUser(t, repo, "uid-owner")
	attacker := createTestUser(t, repo, "uid-attacker")
	cat := createTestCategory(t, repo, owner.ID, "privada")

	rec := doJSON(t, r, http.MethodPost, "/api/expenses", attacker.ID, models.ExpenseInput{
		CategoryID:  cat.ID,
		Amount:      1000,
		ExpenseDate: "2026-08-25",
	})
	if rec.Code == http.StatusCreated {
		t.Fatal("no debería poder crear un gasto con category_id de otro usuario (IDOR)")
	}
}

func TestCreateExpense_InvalidBody(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	req := httptest.NewRequest(http.MethodPost, "/api/expenses", bytes.NewBufferString("{not json"))
	req = withUser(req, user.ID)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusBadRequest)
	}
}

func TestGetExpense_NotFound(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodGet, "/api/expenses/00000000-0000-0000-0000-000000000000", user.ID, nil)
	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
	}
}

func TestListExpenses_EmptyIsEmptyArrayNotNull(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodGet, "/api/expenses", user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.TrimSpace(rec.Body.String()) == "null" {
		t.Error("esperaba [] en vez de null cuando no hay gastos")
	}
}

func TestDeleteExpense(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")
	cat := createTestCategory(t, repo, user.ID, "comida")

	rec := doJSON(t, r, http.MethodPost, "/api/expenses", user.ID, models.ExpenseInput{
		CategoryID: cat.ID, Amount: 500, ExpenseDate: "2026-08-25",
	})
	var created models.Expense
	json.NewDecoder(rec.Body).Decode(&created)

	rec = doJSON(t, r, http.MethodDelete, "/api/expenses/"+created.ID, user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = doJSON(t, r, http.MethodGet, "/api/expenses/"+created.ID, user.ID, nil)
	if rec.Code != http.StatusNotFound {
		t.Error("el gasto debería haber sido eliminado")
	}
}

func TestCategoryCRUD(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodPost, "/api/categories", user.ID, models.Category{
		Name: "transporte", Icon: "bus", Color: "#0F52BA",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST /categories status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var created models.Category
	json.NewDecoder(rec.Body).Decode(&created)

	rec = doJSON(t, r, http.MethodPut, "/api/categories/"+created.ID, user.ID, models.CategoryUpdateInput{
		Name: "transporte publico", Icon: "bus", Color: "#0F52BA",
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT /categories/{id} status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = doJSON(t, r, http.MethodGet, "/api/categories", user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /categories status = %d", rec.Code)
	}
	var list []models.Category
	json.NewDecoder(rec.Body).Decode(&list)
	if len(list) != 1 || list[0].Name != "transporte publico" {
		t.Errorf("esperaba 1 categoría actualizada, got %+v", list)
	}

	rec = doJSON(t, r, http.MethodDelete, "/api/categories/"+created.ID, user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE /categories/{id} status = %d", rec.Code)
	}
}

func TestCardCRUD(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodPost, "/api/cards", user.ID, models.CardInput{
		Name: "Visa Signature", Franchise: "visa", Color: "#1A1C1E", CutOffDay: 5, PaymentDay: 20,
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST /cards status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var created models.Card
	json.NewDecoder(rec.Body).Decode(&created)
	if created.Franchise != "visa" {
		t.Errorf("Franchise = %q, want %q", created.Franchise, "visa")
	}

	rec = doJSON(t, r, http.MethodPut, "/api/cards/"+created.ID, user.ID, models.CardInput{
		Name: "Visa Signature", Franchise: "visa", Color: "#000000", CutOffDay: 10, PaymentDay: 25,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT /cards/{id} status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = doJSON(t, r, http.MethodDelete, "/api/cards/"+created.ID, user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE /cards/{id} status = %d", rec.Code)
	}
}

func TestCardCreate_InvalidCutOffDay(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodPost, "/api/cards", user.ID, models.CardInput{
		Name: "Bad", Franchise: "visa", CutOffDay: 32, PaymentDay: 5,
	})
	if rec.Code == http.StatusCreated {
		t.Error("no debería aceptar cut_off_day fuera de 1-31")
	}
}

func TestPresetCRUD(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")
	cat := createTestCategory(t, repo, user.ID, "transporte")

	rec := doJSON(t, r, http.MethodGet, "/api/presets", user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /presets status = %d, body = %s", rec.Code, rec.Body.String())
	}
	if strings.TrimSpace(rec.Body.String()) == "null" {
		t.Error("esperaba [] en vez de null cuando no hay presets")
	}

	rec = doJSON(t, r, http.MethodPost, "/api/presets", user.ID, models.PresetInput{
		Name: "Flota Tunja-Bogotá", Icon: "🚌", Amount: 25000, CategoryID: cat.ID, Description: "pasajes",
	})
	if rec.Code != http.StatusCreated {
		t.Fatalf("POST /presets status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var created models.Preset
	json.NewDecoder(rec.Body).Decode(&created)
	if created.ID == "" {
		t.Fatal("esperaba un ID asignado")
	}
	if created.CategoryID != cat.ID {
		t.Errorf("CategoryID = %q, want %q", created.CategoryID, cat.ID)
	}

	rec = doJSON(t, r, http.MethodPut, "/api/presets/"+created.ID, user.ID, models.PresetInput{
		Name: "Flota", Icon: "🚌", Amount: 27000, CategoryID: cat.ID,
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT /presets/{id} status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var updated models.Preset
	json.NewDecoder(rec.Body).Decode(&updated)
	if updated.Name != "Flota" || updated.Amount != 27000 {
		t.Errorf("preset no actualizado: %+v", updated)
	}

	rec = doJSON(t, r, http.MethodGet, "/api/presets", user.ID, nil)
	var list []models.Preset
	json.NewDecoder(rec.Body).Decode(&list)
	if len(list) != 1 || list[0].Name != "Flota" {
		t.Errorf("esperaba 1 preset actualizado, got %+v", list)
	}

	rec = doJSON(t, r, http.MethodDelete, "/api/presets/"+created.ID, user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("DELETE /presets/{id} status = %d", rec.Code)
	}
	rec = doJSON(t, r, http.MethodGet, "/api/presets", user.ID, nil)
	json.NewDecoder(rec.Body).Decode(&list)
	if len(list) != 0 {
		t.Errorf("esperaba 0 presets tras eliminar, got %+v", list)
	}
}

func TestCreatePreset_RejectsCategoryFromAnotherUser(t *testing.T) {
	r, repo := newTestRouter(t)
	owner := createTestUser(t, repo, "uid-owner")
	attacker := createTestUser(t, repo, "uid-attacker")
	cat := createTestCategory(t, repo, owner.ID, "privada")

	rec := doJSON(t, r, http.MethodPost, "/api/presets", attacker.ID, models.PresetInput{
		Name: "Robado", Amount: 1000, CategoryID: cat.ID,
	})
	if rec.Code == http.StatusCreated {
		t.Fatal("no debería poder crear un preset con category_id de otro usuario (IDOR)")
	}
}

func TestProfile_GetAndUpdate(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodGet, "/api/users/profile", user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /users/profile status = %d, body = %s", rec.Code, rec.Body.String())
	}

	rec = doJSON(t, r, http.MethodPut, "/api/users/profile", user.ID, models.UserProfileInput{
		DisplayName: "User", Avatar: "🐱",
	})
	if rec.Code != http.StatusOK {
		t.Fatalf("PUT /users/profile status = %d, body = %s", rec.Code, rec.Body.String())
	}
	var updated models.User
	json.NewDecoder(rec.Body).Decode(&updated)
	if updated.DisplayName != "User" {
		t.Errorf("DisplayName = %q, want %q", updated.DisplayName, "User")
	}
}

func TestGetStats_EmptyOK(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := doJSON(t, r, http.MethodGet, "/api/stats", user.ID, nil)
	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", rec.Code, rec.Body.String())
	}
}

func TestWriteInternalError_DoesNotLeakErrorDetails(t *testing.T) {
	rec := httptest.NewRecorder()
	writeInternalError(rec, errors.New(`pq: relation "secret_internal_table" does not exist`))

	if rec.Code != http.StatusInternalServerError {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusInternalServerError)
	}
	if strings.Contains(rec.Body.String(), "secret_internal_table") {
		t.Error("la respuesta no debería exponer detalles internos del error")
	}
	var body map[string]string
	if err := json.NewDecoder(rec.Body).Decode(&body); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if body["error"] != "internal error" {
		t.Errorf(`error = %q, want "internal error"`, body["error"])
	}
}

func uploadFile(t *testing.T, r *chi.Mux, path, userID, filename string, content []byte) *httptest.ResponseRecorder {
	t.Helper()
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", filename)
	if err != nil {
		t.Fatalf("CreateFormFile: %v", err)
	}
	if _, err := part.Write(content); err != nil {
		t.Fatalf("write file content: %v", err)
	}
	if err := writer.Close(); err != nil {
		t.Fatalf("close writer: %v", err)
	}

	req := httptest.NewRequest(http.MethodPost, path, &body)
	req.Header.Set("Content-Type", writer.FormDataContentType())
	req = withUser(req, userID)
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, req)
	return rec
}

func TestUploadReceipt_RejectsUnsupportedFileType(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := uploadFile(t, r, "/api/expenses/receipt", user.ID, "not-a-photo.txt", []byte("esto no es una imagen"))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d, body = %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}

func TestUploadReceipt_SpoofedContentTypeStillRejected(t *testing.T) {
	// El Content-Type real del multipart writer para este part queda como
	// texto plano; el ataque es intentar que el backend confíe en un nombre
	// de archivo con extensión de imagen sin serlo realmente.
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := uploadFile(t, r, "/api/expenses/receipt", user.ID, "fake.jpg", []byte("<script>no soy una imagen</script>"))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d — el nombre .jpg no debería bastar para pasar la validación de magic bytes", rec.Code, http.StatusBadRequest)
	}
}

func TestUploadVoice_RejectsUnsupportedFileType(t *testing.T) {
	r, repo := newTestRouter(t)
	user := createTestUser(t, repo, "uid-1")

	rec := uploadFile(t, r, "/api/expenses/voice", user.ID, "not-audio.txt", []byte("esto no es audio"))
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("status = %d, want %d, body = %s", rec.Code, http.StatusBadRequest, rec.Body.String())
	}
}
