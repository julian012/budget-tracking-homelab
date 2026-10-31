package handler

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/middleware"
	"github.com/example/budget-tracking-homelab/backend/internal/models"
	"github.com/example/budget-tracking-homelab/backend/internal/service"

	"github.com/go-chi/chi/v5"
)

type ExpenseHandler struct {
	svc *service.ExpenseService
}

func NewExpenseHandler(svc *service.ExpenseService) *ExpenseHandler {
	return &ExpenseHandler{svc: svc}
}

func (h *ExpenseHandler) RegisterRoutes(r chi.Router) {
	r.Route("/api", func(r chi.Router) {
		r.Get("/expenses", h.ListExpenses)
		r.Post("/expenses", h.CreateExpense)
		r.Get("/expenses/{id}", h.GetExpense)
		r.Put("/expenses/{id}", h.UpdateExpense)
		r.Delete("/expenses/{id}", h.DeleteExpense)
		r.Post("/expenses/receipt", h.UploadReceipt)
		r.Post("/expenses/voice", h.UploadVoice)
		r.Get("/categories", h.ListCategories)
		r.Post("/categories", h.CreateCategory)
		r.Put("/categories/{id}", h.UpdateCategory)
		r.Delete("/categories/{id}", h.DeleteCategory)
		r.Get("/users/profile", h.GetProfile)
		r.Put("/users/profile", h.UpdateProfile)
		r.Get("/cards", h.ListCards)
		r.Post("/cards", h.CreateCard)
		r.Put("/cards/{id}", h.UpdateCard)
		r.Delete("/cards/{id}", h.DeleteCard)
		r.Get("/presets", h.ListPresets)
		r.Post("/presets", h.CreatePreset)
		r.Put("/presets/{id}", h.UpdatePreset)
		r.Delete("/presets/{id}", h.DeletePreset)
		r.Get("/stats", h.GetStats)

		r.Get("/people", h.ListPeople)
		r.Post("/people", h.CreatePerson)
		r.Put("/people/{id}", h.UpdatePerson)
		r.Delete("/people/{id}", h.DeletePerson)
		r.Post("/people/{id}/archive", h.ArchivePerson)
		r.Post("/people/{id}/unarchive", h.UnarchivePerson)
		r.Get("/people/{id}/shares", h.ListPersonShares)
		r.Get("/people/{id}/payments", h.ListPersonPayments)
		r.Post("/people/{id}/payments", h.CreatePersonPayment)
		r.Delete("/payments/{id}", h.DeletePersonPayment)
		r.Get("/shared/summary", h.GetSharedSummary)
	})
}

func (h *ExpenseHandler) ListExpenses(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	q := r.URL.Query()
	expenses, err := h.svc.GetExpenses(r.Context(), userID, q.Get("start_date"), q.Get("end_date"), q.Get("category_id"))
	if err != nil {
		writeInternalError(w, err)
		return
	}
	if expenses == nil {
		expenses = []models.Expense{}
	}
	writeJSON(w, http.StatusOK, expenses)
}

func (h *ExpenseHandler) CreateExpense(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var input models.ExpenseInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	if input.Source == "" {
		input.Source = "form"
	}
	if input.ExpenseDate == "" {
		input.ExpenseDate = time.Now().Format("2006-01-02")
	}

	expense, err := h.svc.CreateExpense(r.Context(), userID, input)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, expense)
}

func (h *ExpenseHandler) GetExpense(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")

	expense, err := h.svc.GetExpense(r.Context(), id, userID)
	if err != nil {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	writeJSON(w, http.StatusOK, expense)
}

func (h *ExpenseHandler) UpdateExpense(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")

	var input models.ExpenseInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}

	expense, err := h.svc.UpdateExpense(r.Context(), userID, id, input)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, expense)
}

func (h *ExpenseHandler) DeleteExpense(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")

	if err := h.svc.DeleteExpense(r.Context(), id, userID); err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

// allowedReceiptTypes/allowedAudioTypes validan el tipo real del archivo
// (magic bytes vía http.DetectContentType), no el header Content-Type que
// manda el cliente y puede venir falsificado.
var allowedReceiptTypes = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
}

var allowedAudioTypes = map[string]bool{
	"audio/mpeg":      true,
	"audio/wave":      true,
	"audio/x-wav":     true,
	"audio/ogg":       true,
	"application/ogg": true,
	"video/ogg":       true, // http.DetectContentType clasifica algunos .ogg de solo audio como video/ogg
}

func (h *ExpenseHandler) UploadReceipt(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	r.Body = http.MaxBytesReader(w, r.Body, 10<<20)
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "file too large"})
		return
	}

	file, _, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "file required"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "read file"})
		return
	}

	contentType := http.DetectContentType(data)
	if !allowedReceiptTypes[contentType] {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "unsupported file type"})
		return
	}

	expense, err := h.svc.ProcessReceipt(r.Context(), userID, data, contentType)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, expense)
}

func (h *ExpenseHandler) UploadVoice(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	r.Body = http.MaxBytesReader(w, r.Body, 10<<20)
	if err := r.ParseMultipartForm(10 << 20); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "file too large"})
		return
	}

	file, _, err := r.FormFile("file")
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "file required"})
		return
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "read file"})
		return
	}

	contentType := http.DetectContentType(data)
	if !allowedAudioTypes[contentType] {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "unsupported file type"})
		return
	}

	expense, err := h.svc.ProcessVoice(r.Context(), userID, data, contentType)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, expense)
}

func (h *ExpenseHandler) ListCategories(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	categories, err := h.svc.GetCategories(r.Context(), userID)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	if categories == nil {
		categories = []models.Category{}
	}
	writeJSON(w, http.StatusOK, categories)
}

func (h *ExpenseHandler) CreateCategory(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var category models.Category
	if err := json.NewDecoder(r.Body).Decode(&category); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}

	created, err := h.svc.CreateCategory(r.Context(), userID, &category)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, created)
}

func (h *ExpenseHandler) UpdateCategory(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")

	var input models.CategoryUpdateInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}

	updated, err := h.svc.UpdateCategory(r.Context(), userID, id, input)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, updated)
}

func (h *ExpenseHandler) DeleteCategory(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")

	if err := h.svc.DeleteCategory(r.Context(), id, userID); err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *ExpenseHandler) GetStats(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)

	var startDate, endDate time.Time
	if s := r.URL.Query().Get("start_date"); s != "" {
		startDate, _ = time.Parse("2006-01-02", s)
	}
	if e := r.URL.Query().Get("end_date"); e != "" {
		endDate, _ = time.Parse("2006-01-02", e)
	}

	stats, err := h.svc.GetStats(r.Context(), userID, startDate, endDate, r.URL.Query().Get("type"))
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, stats)
}

func (h *ExpenseHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	user, err := h.svc.GetUserProfile(r.Context(), userID)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (h *ExpenseHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var input models.UserProfileInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	user, err := h.svc.UpdateUserProfile(r.Context(), userID, input)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, user)
}

func (h *ExpenseHandler) ListCards(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	cards, err := h.svc.GetCards(r.Context(), userID)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	if cards == nil {
		cards = []models.Card{}
	}
	writeJSON(w, http.StatusOK, cards)
}

func (h *ExpenseHandler) CreateCard(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var input models.CardInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	card, err := h.svc.CreateCard(r.Context(), userID, input)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, card)
}

func (h *ExpenseHandler) UpdateCard(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	var input models.CardInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	card, err := h.svc.UpdateCard(r.Context(), userID, id, input)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, card)
}

func (h *ExpenseHandler) DeleteCard(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	if err := h.svc.DeleteCard(r.Context(), id, userID); err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *ExpenseHandler) ListPresets(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	presets, err := h.svc.GetPresets(r.Context(), userID)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	if presets == nil {
		presets = []models.Preset{}
	}
	writeJSON(w, http.StatusOK, presets)
}

func (h *ExpenseHandler) CreatePreset(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var input models.PresetInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	preset, err := h.svc.CreatePreset(r.Context(), userID, input)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, preset)
}

func (h *ExpenseHandler) UpdatePreset(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	var input models.PresetInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	preset, err := h.svc.UpdatePreset(r.Context(), userID, id, input)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, preset)
}

func (h *ExpenseHandler) DeletePreset(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	if err := h.svc.DeletePreset(r.Context(), id, userID); err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func writeJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		// El status ya fue enviado, no se puede cambiar la respuesta: se
		// loguea para poder diagnosticar respuestas truncadas/serialización fallida.
		log.Printf("handler: writeJSON encode: %v", err)
	}
}

// writeInternalError loguea el error completo server-side (con su contexto
// interno vía fmt.Errorf) y devuelve un mensaje genérico y consistente al
// cliente, en vez de exponer detalles de implementación (nombres de tabla,
// mensajes del driver pgx, etc.) en la respuesta HTTP.
func writeInternalError(w http.ResponseWriter, err error) {
	log.Printf("handler: internal error: %v", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
}

// writeServiceError mapea errores de dominio conocidos a códigos HTTP.
func writeServiceError(w http.ResponseWriter, err error) {
	msg := err.Error()
	if strings.Contains(msg, "not found") {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
		return
	}
	conflictMsgs := []string{
		"has pending debt",
		"has history",
		"has payments",
		"below paid amount",
		"remove share with payments",
		"payment exceeds pending amount",
	}
	for _, cm := range conflictMsgs {
		if strings.Contains(msg, cm) {
			writeJSON(w, http.StatusConflict, map[string]string{"error": msg})
			return
		}
	}
	writeJSON(w, http.StatusBadRequest, map[string]string{"error": msg})
}

func (h *ExpenseHandler) ListPeople(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	includeArchived := r.URL.Query().Get("include_archived") == "true"
	people, err := h.svc.GetPeople(r.Context(), userID, includeArchived)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	if people == nil {
		people = []models.Person{}
	}
	writeJSON(w, http.StatusOK, people)
}

func (h *ExpenseHandler) CreatePerson(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	var input models.PersonInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	person, err := h.svc.CreatePerson(r.Context(), userID, input)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, person)
}

func (h *ExpenseHandler) UpdatePerson(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	var input models.PersonInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	person, err := h.svc.UpdatePerson(r.Context(), userID, id, input)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, person)
}

func (h *ExpenseHandler) DeletePerson(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	if err := h.svc.DeletePerson(r.Context(), userID, id); err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *ExpenseHandler) ArchivePerson(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	if err := h.svc.ArchivePerson(r.Context(), userID, id, true); err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "archived"})
}

func (h *ExpenseHandler) UnarchivePerson(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	if err := h.svc.ArchivePerson(r.Context(), userID, id, false); err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "unarchived"})
}

func (h *ExpenseHandler) ListPersonShares(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	status := r.URL.Query().Get("status")
	if status == "" {
		status = "all"
	}
	shares, err := h.svc.GetPersonShares(r.Context(), userID, id, status)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	if shares == nil {
		shares = []models.PersonShareExpense{}
	}
	writeJSON(w, http.StatusOK, shares)
}

func (h *ExpenseHandler) ListPersonPayments(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	payments, err := h.svc.ListPersonPayments(r.Context(), userID, id)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	if payments == nil {
		payments = []models.PersonPayment{}
	}
	writeJSON(w, http.StatusOK, payments)
}

type createPaymentRequest struct {
	Amount float64 `json:"amount"`
	PaidAt string  `json:"paid_at"`
	Note   string  `json:"note"`
}

func (h *ExpenseHandler) CreatePersonPayment(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	var req createPaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid body"})
		return
	}
	payment, err := h.svc.CreatePersonPayment(r.Context(), userID, id, req.Amount, req.PaidAt, req.Note)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, payment)
}

func (h *ExpenseHandler) DeletePersonPayment(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	id := chi.URLParam(r, "id")
	if err := h.svc.DeletePersonPayment(r.Context(), userID, id); err != nil {
		writeServiceError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"message": "deleted"})
}

func (h *ExpenseHandler) GetSharedSummary(w http.ResponseWriter, r *http.Request) {
	userID := middleware.GetUserID(r)
	summary, err := h.svc.GetSharedSummary(r.Context(), userID)
	if err != nil {
		writeInternalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, summary)
}
