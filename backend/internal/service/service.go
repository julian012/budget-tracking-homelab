package service

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
	"github.com/example/budget-tracking-homelab/backend/internal/repository"

	"github.com/google/uuid"
)

// Uploader es la interfaz mínima de storage que consume ExpenseService
// (patrón usado para middleware.UserRepo en #39/#40): permite inyectar un
// fake en los tests sin necesitar un MinIO real. *storage.MinioClient la
// satisface implícitamente.
type Uploader interface {
	EnsureBuckets(ctx context.Context) error
	UploadReceipt(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error)
	UploadAudio(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error)
}

type ExpenseService struct {
	repo       repository.ExpenseRepo
	storage    Uploader
	aiEndpoint string
	aiApiKey   string
}

func NewExpenseService(repo repository.ExpenseRepo, st Uploader, aiEndpoint, aiApiKey string) *ExpenseService {
	return &ExpenseService{
		repo:       repo,
		storage:    st,
		aiEndpoint: aiEndpoint,
		aiApiKey:   aiApiKey,
	}
}

func (s *ExpenseService) CreateExpense(ctx context.Context, userID string, input models.ExpenseInput) (*models.Expense, error) {
	if err := s.validateExpenseRefs(ctx, userID, input); err != nil {
		return nil, err
	}
	if err := s.validateShares(ctx, userID, input.Amount, input.TransactionGroupID, input.Shares); err != nil {
		return nil, err
	}

	date, err := time.Parse("2006-01-02", input.ExpenseDate)
	if err != nil {
		date = time.Now()
	}

	expense := &models.Expense{
		UserID:             userID,
		CategoryID:         input.CategoryID,
		CardID:             input.CardID,
		Amount:             input.Amount,
		Description:        input.Description,
		ExpenseDate:        date,
		Source:             input.Source,
		TransactionGroupID: input.TransactionGroupID,
	}

	if err := s.repo.Create(ctx, expense); err != nil {
		return nil, fmt.Errorf("create expense: %w", err)
	}
	if len(input.Shares) > 0 {
		if err := s.repo.ReplaceExpenseShares(ctx, expense.ID, userID, input.Shares); err != nil {
			return nil, fmt.Errorf("save shares: %w", err)
		}
	}
	return s.repo.GetExpenseByID(ctx, expense.ID, userID)
}

// validateExpenseRefs verifica que category_id/card_id (si vienen en el input)
// pertenezcan al usuario autenticado, para evitar que un gasto quede
// referenciando una categoría o tarjeta de otro usuario (IDOR).
func (s *ExpenseService) validateExpenseRefs(ctx context.Context, userID string, input models.ExpenseInput) error {
	if input.CategoryID != "" {
		if _, err := s.repo.GetCategoryByID(ctx, input.CategoryID, userID); err != nil {
			return fmt.Errorf("category not found: %w", err)
		}
	}
	if input.CardID != nil && *input.CardID != "" {
		if _, err := s.repo.GetCardByID(ctx, *input.CardID, userID); err != nil {
			return fmt.Errorf("card not found: %w", err)
		}
	}
	return nil
}

func (s *ExpenseService) ProcessReceipt(ctx context.Context, userID string, imageData []byte, contentType string) (*models.Expense, error) {
	objectName := fmt.Sprintf("%s%s", uuid.New().String(), extForContentType(contentType, ".jpg"))
	url, err := s.storage.UploadReceipt(ctx, objectName, bytes.NewReader(imageData), int64(len(imageData)), contentType)
	if err != nil {
		return nil, fmt.Errorf("upload receipt: %w", err)
	}

	parsed, err := s.parseExpenseWithAI(ctx, imageData, "image")
	if err != nil {
		expense := &models.Expense{
			UserID:      userID,
			Amount:      0,
			Description: "Factura sin procesar",
			ExpenseDate: time.Now(),
			Source:      "camera",
			ReceiptURL:  url,
		}
		if createErr := s.repo.Create(ctx, expense); createErr != nil {
			return nil, fmt.Errorf("create expense: %w", createErr)
		}
		return expense, nil
	}

	categoryID, err := s.findOrCreateCategory(ctx, userID, parsed.Category)
	if err != nil {
		return nil, err
	}

	date, _ := time.Parse("2006-01-02", parsed.Date)
	if date.IsZero() {
		date = time.Now()
	}

	expense := &models.Expense{
		UserID:      userID,
		CategoryID:  categoryID,
		Amount:      parsed.Amount,
		Description: parsed.Description,
		ExpenseDate: date,
		Source:      "camera",
		ReceiptURL:  url,
	}

	if err := s.repo.Create(ctx, expense); err != nil {
		return nil, fmt.Errorf("create expense: %w", err)
	}
	return expense, nil
}

func (s *ExpenseService) ProcessVoice(ctx context.Context, userID string, audioData []byte, contentType string) (*models.Expense, error) {
	objectName := fmt.Sprintf("%s%s", uuid.New().String(), extForContentType(contentType, ".ogg"))
	url, err := s.storage.UploadAudio(ctx, objectName, bytes.NewReader(audioData), int64(len(audioData)), contentType)
	if err != nil {
		return nil, fmt.Errorf("upload audio: %w", err)
	}

	parsed, err := s.parseExpenseWithAI(ctx, audioData, "audio")
	if err != nil {
		expense := &models.Expense{
			UserID:      userID,
			Amount:      0,
			Description: "Audio sin procesar",
			ExpenseDate: time.Now(),
			Source:      "voice",
			AudioURL:    url,
		}
		if createErr := s.repo.Create(ctx, expense); createErr != nil {
			return nil, fmt.Errorf("create expense: %w", createErr)
		}
		return expense, nil
	}

	categoryID, err := s.findOrCreateCategory(ctx, userID, parsed.Category)
	if err != nil {
		return nil, err
	}

	date, _ := time.Parse("2006-01-02", parsed.Date)
	if date.IsZero() {
		date = time.Now()
	}

	expense := &models.Expense{
		UserID:      userID,
		CategoryID:  categoryID,
		Amount:      parsed.Amount,
		Description: parsed.Description,
		ExpenseDate: date,
		Source:      "voice",
		AudioURL:    url,
	}

	if err := s.repo.Create(ctx, expense); err != nil {
		return nil, fmt.Errorf("create expense: %w", err)
	}
	return expense, nil
}

func (s *ExpenseService) parseExpenseWithAI(ctx context.Context, data []byte, mediaType string) (*models.AIParsedExpense, error) {
	if s.aiApiKey == "" || s.aiEndpoint == "" {
		return nil, fmt.Errorf("AI not configured")
	}

	b64Data := base64.StdEncoding.EncodeToString(data)

	prompt := `Eres un asistente que extrae información de gastos. Analiza el contenido y devuelve un JSON con estos campos:
- amount (número, monto del gasto)
- description (texto corto, qué se compró)
- date (YYYY-MM-DD, fecha del gasto)
- category (texto, categoría: "alimentos", "transporte", "servicios", "entretenimiento", "salud", "educacion", "hogar", "ropa", "otros")

Responde SOLO con el JSON, sin texto adicional.`

	reqBody := map[string]interface{}{
		"model": "deepseek-v4-pro",
		"messages": []map[string]interface{}{
			{"role": "user", "content": prompt},
		},
		"temperature": 0.1,
	}

	if mediaType == "image" {
		reqBody["messages"].([]map[string]interface{})[0]["content"] = []map[string]interface{}{
			{"type": "text", "text": prompt},
			{"type": "image_url", "image_url": map[string]string{"url": fmt.Sprintf("data:image/jpeg;base64,%s", b64Data)}},
		}
	} else {
		reqBody["messages"].([]map[string]interface{})[0]["content"] = fmt.Sprintf("Transcripción de audio del usuario: (el audio contiene información sobre un gasto)\n\n%s", prompt)
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("marshal AI request: %w", err)
	}
	httpReq, err := http.NewRequestWithContext(ctx, "POST", s.aiEndpoint+"/chat/completions", bytes.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("build AI request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+s.aiApiKey)

	resp, err := http.DefaultClient.Do(httpReq)
	if err != nil {
		return nil, fmt.Errorf("AI request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read AI response: %w", err)
	}

	var aiResp struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.Unmarshal(respBody, &aiResp); err != nil {
		return nil, fmt.Errorf("AI response parse: %w", err)
	}

	if len(aiResp.Choices) == 0 {
		return nil, fmt.Errorf("empty AI response")
	}

	content := aiResp.Choices[0].Message.Content
	content = extractJSON(content)

	var parsed models.AIParsedExpense
	if err := json.Unmarshal([]byte(content), &parsed); err != nil {
		return nil, fmt.Errorf("parse AI extracted data: %w", err)
	}

	return &parsed, nil
}

func extractJSON(content string) string {
	start := 0
	end := len(content)
	for i, c := range content {
		if c == '{' {
			start = i
			break
		}
	}
	for i := len(content) - 1; i >= 0; i-- {
		if content[i] == '}' {
			end = i + 1
			break
		}
	}
	if start < end {
		return content[start:end]
	}
	return content
}

func (s *ExpenseService) findOrCreateCategory(ctx context.Context, userID, name string) (string, error) {
	if name == "" {
		name = "otros"
	}

	categories, err := s.repo.GetCategories(ctx, userID)
	if err != nil {
		return "", err
	}

	for _, c := range categories {
		if c.Name == name {
			return c.ID, nil
		}
	}

	cat := &models.Category{Name: name, Icon: "tag", Color: "#6B7280", UserID: userID}
	if err := s.repo.CreateCategory(ctx, cat); err != nil {
		return "", fmt.Errorf("create category: %w", err)
	}
	return cat.ID, nil
}

func (s *ExpenseService) GetExpenses(ctx context.Context, userID, startDate, endDate, categoryID string) ([]models.Expense, error) {
	var start, end time.Time
	if startDate != "" {
		start, _ = time.Parse("2006-01-02", startDate)
	}
	if endDate != "" {
		end, _ = time.Parse("2006-01-02", endDate)
	}
	return s.repo.GetExpenses(ctx, userID, start, end, categoryID)
}

func (s *ExpenseService) GetExpense(ctx context.Context, id, userID string) (*models.Expense, error) {
	return s.repo.GetExpenseByID(ctx, id, userID)
}

func (s *ExpenseService) UpdateExpense(ctx context.Context, userID string, id string, input models.ExpenseInput) (*models.Expense, error) {
	if err := s.validateExpenseRefs(ctx, userID, input); err != nil {
		return nil, err
	}
	if input.Shares != nil {
		if err := s.validateShares(ctx, userID, input.Amount, input.TransactionGroupID, input.Shares); err != nil {
			return nil, err
		}
	}

	date, err := time.Parse("2006-01-02", input.ExpenseDate)
	if err != nil {
		date = time.Now()
	}

	expense := &models.Expense{
		ID:          id,
		UserID:      userID,
		CategoryID:  input.CategoryID,
		CardID:      input.CardID,
		Amount:      input.Amount,
		Description: input.Description,
		ExpenseDate: date,
		Source:      input.Source,
	}

	if err := s.repo.UpdateExpense(ctx, expense); err != nil {
		return nil, fmt.Errorf("update expense: %w", err)
	}
	if input.Shares != nil {
		if err := s.repo.ReplaceExpenseShares(ctx, id, userID, input.Shares); err != nil {
			return nil, fmt.Errorf("save shares: %w", err)
		}
	}
	return s.repo.GetExpenseByID(ctx, id, userID)
}

func (s *ExpenseService) DeleteExpense(ctx context.Context, id, userID string) error {
	count, err := s.repo.CountPaymentAllocationsForExpense(ctx, id, userID)
	if err != nil {
		return fmt.Errorf("check expense payments: %w", err)
	}
	if count > 0 {
		return fmt.Errorf("expense has payments")
	}
	return s.repo.DeleteExpense(ctx, id, userID)
}

func (s *ExpenseService) GetCategories(ctx context.Context, userID string) ([]models.Category, error) {
	return s.repo.GetCategories(ctx, userID)
}

func (s *ExpenseService) CreateCategory(ctx context.Context, userID string, category *models.Category) (*models.Category, error) {
	category.UserID = userID
	if err := s.repo.CreateCategory(ctx, category); err != nil {
		return nil, err
	}
	return category, nil
}

func (s *ExpenseService) UpdateCategory(ctx context.Context, userID string, id string, input models.CategoryUpdateInput) (*models.Category, error) {
	categories, err := s.repo.GetCategories(ctx, userID)
	if err != nil {
		return nil, err
	}
	var cat *models.Category
	for i := range categories {
		if categories[i].ID == id {
			cat = &categories[i]
			break
		}
	}
	if cat == nil {
		return nil, fmt.Errorf("category not found")
	}
	cat.Name = input.Name
	cat.Icon = input.Icon
	cat.Color = input.Color
	cat.Type = input.Type
	cat.RequiresDescription = input.RequiresDescription
	cat.DefaultAmount = input.DefaultAmount
	if err := s.repo.UpdateCategory(ctx, cat); err != nil {
		return nil, err
	}
	return cat, nil
}

func (s *ExpenseService) DeleteCategory(ctx context.Context, id, userID string) error {
	return s.repo.DeleteCategory(ctx, id, userID)
}

func (s *ExpenseService) GetStats(ctx context.Context, userID string, startDate, endDate time.Time, expenseType string) (*models.StatsSummary, error) {
	return s.repo.GetStats(ctx, userID, startDate, endDate, expenseType)
}

func (s *ExpenseService) GetUserProfile(ctx context.Context, userID string) (*models.User, error) {
	return s.repo.GetUserByID(ctx, userID)
}

func (s *ExpenseService) UpdateUserProfile(ctx context.Context, userID string, input models.UserProfileInput) (*models.User, error) {
	user, err := s.repo.GetUserByID(ctx, userID)
	if err != nil {
		return nil, err
	}
	user.DisplayName = input.DisplayName
	user.Avatar = input.Avatar
	if err := s.repo.UpdateUserProfile(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

func (s *ExpenseService) CreateCard(ctx context.Context, userID string, input models.CardInput) (*models.Card, error) {
	if input.CutOffDay < 1 || input.CutOffDay > 31 || input.PaymentDay < 1 || input.PaymentDay > 31 {
		return nil, fmt.Errorf("days must be between 1 and 31")
	}
	franchise := normalizeFranchise(input.Franchise)
	card := &models.Card{
		UserID:      userID,
		Name:        input.Name,
		Franchise:   franchise,
		Color:       input.Color,
		CutOffDay:   input.CutOffDay,
		PaymentDay:  input.PaymentDay,
		CreditLimit: input.CreditLimit,
	}
	if err := s.repo.CreateCard(ctx, card); err != nil {
		return nil, err
	}
	return card, nil
}

func (s *ExpenseService) GetCards(ctx context.Context, userID string) ([]models.Card, error) {
	return s.repo.GetCards(ctx, userID)
}

func (s *ExpenseService) UpdateCard(ctx context.Context, userID string, id string, input models.CardInput) (*models.Card, error) {
	if input.CutOffDay < 1 || input.CutOffDay > 31 || input.PaymentDay < 1 || input.PaymentDay > 31 {
		return nil, fmt.Errorf("days must be between 1 and 31")
	}
	card, err := s.repo.GetCardByID(ctx, id, userID)
	if err != nil {
		return nil, err
	}
	card.Name = input.Name
	card.Franchise = normalizeFranchise(input.Franchise)
	card.Color = input.Color
	card.CutOffDay = input.CutOffDay
	card.PaymentDay = input.PaymentDay
	card.CreditLimit = input.CreditLimit
	if err := s.repo.UpdateCard(ctx, card); err != nil {
		return nil, err
	}
	return card, nil
}

func (s *ExpenseService) DeleteCard(ctx context.Context, id, userID string) error {
	return s.repo.DeleteCard(ctx, id, userID)
}

func (s *ExpenseService) GetPresets(ctx context.Context, userID string) ([]models.Preset, error) {
	return s.repo.GetPresets(ctx, userID)
}

func (s *ExpenseService) CreatePreset(ctx context.Context, userID string, input models.PresetInput) (*models.Preset, error) {
	if strings.TrimSpace(input.Name) == "" {
		return nil, fmt.Errorf("name is required")
	}
	if err := s.validatePresetRefs(ctx, userID, input.CategoryID, input.CardID); err != nil {
		return nil, err
	}
	preset := &models.Preset{
		UserID:      userID,
		Name:        input.Name,
		Icon:        input.Icon,
		Amount:      input.Amount,
		CategoryID:  input.CategoryID,
		CardID:      input.CardID,
		Description: input.Description,
	}
	if err := s.repo.CreatePreset(ctx, preset); err != nil {
		return nil, fmt.Errorf("create preset: %w", err)
	}
	return preset, nil
}

func (s *ExpenseService) UpdatePreset(ctx context.Context, userID, id string, input models.PresetInput) (*models.Preset, error) {
	if strings.TrimSpace(input.Name) == "" {
		return nil, fmt.Errorf("name is required")
	}
	if err := s.validatePresetRefs(ctx, userID, input.CategoryID, input.CardID); err != nil {
		return nil, err
	}
	preset, err := s.repo.GetPresetByID(ctx, id, userID)
	if err != nil {
		return nil, err
	}
	preset.Name = input.Name
	preset.Icon = input.Icon
	preset.Amount = input.Amount
	preset.CategoryID = input.CategoryID
	preset.CardID = input.CardID
	preset.Description = input.Description
	if err := s.repo.UpdatePreset(ctx, preset); err != nil {
		return nil, fmt.Errorf("update preset: %w", err)
	}
	return preset, nil
}

func (s *ExpenseService) DeletePreset(ctx context.Context, id, userID string) error {
	return s.repo.DeletePreset(ctx, id, userID)
}

// validateShares verifica que las participaciones sean coherentes y que cada
// persona pertenezca al usuario autenticado.
func (s *ExpenseService) validateShares(ctx context.Context, userID string, amount float64, transactionGroupID *string, shares []models.ExpenseShareInput) error {
	if len(shares) == 0 {
		return nil
	}
	if transactionGroupID != nil && *transactionGroupID != "" {
		return fmt.Errorf("shared expense cannot have sub-expenses")
	}
	seen := make(map[string]bool, len(shares))
	var sum float64
	for _, sh := range shares {
		if sh.PersonID == "" {
			return fmt.Errorf("person_id is required")
		}
		if seen[sh.PersonID] {
			return fmt.Errorf("duplicate person in shares")
		}
		seen[sh.PersonID] = true
		if sh.Amount <= 0 {
			return fmt.Errorf("share amount must be greater than zero")
		}
		sum += sh.Amount
		if _, err := s.repo.GetPersonByID(ctx, sh.PersonID, userID); err != nil {
			return fmt.Errorf("person not found: %w", err)
		}
	}
	if sum > amount {
		return fmt.Errorf("shares exceed expense amount")
	}
	return nil
}

func (s *ExpenseService) GetPeople(ctx context.Context, userID string, includeArchived bool) ([]models.Person, error) {
	return s.repo.ListPeople(ctx, userID, includeArchived)
}

func (s *ExpenseService) CreatePerson(ctx context.Context, userID string, input models.PersonInput) (*models.Person, error) {
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		return nil, fmt.Errorf("name is required")
	}
	if input.Color == "" {
		input.Color = "#6B7280"
	}
	if input.Icon == "" {
		input.Icon = "user"
	}
	person := &models.Person{
		UserID:   userID,
		Name:     input.Name,
		Color:    input.Color,
		Icon:     input.Icon,
		Archived: input.Archived,
	}
	if err := s.repo.CreatePerson(ctx, person); err != nil {
		return nil, fmt.Errorf("create person: %w", err)
	}
	return person, nil
}

func (s *ExpenseService) UpdatePerson(ctx context.Context, userID, id string, input models.PersonInput) (*models.Person, error) {
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" {
		return nil, fmt.Errorf("name is required")
	}
	person, err := s.repo.GetPersonByID(ctx, id, userID)
	if err != nil {
		return nil, err
	}
	person.Name = input.Name
	if input.Color != "" {
		person.Color = input.Color
	}
	if input.Icon != "" {
		person.Icon = input.Icon
	}
	if err := s.repo.UpdatePerson(ctx, person); err != nil {
		return nil, fmt.Errorf("update person: %w", err)
	}
	return person, nil
}

func (s *ExpenseService) ArchivePerson(ctx context.Context, userID, id string, archived bool) error {
	if archived {
		pending, err := s.repo.GetPersonPendingTotal(ctx, id, userID)
		if err != nil {
			return fmt.Errorf("check pending: %w", err)
		}
		if pending > 0 {
			return fmt.Errorf("person has pending debt")
		}
	}
	return s.repo.ArchivePerson(ctx, id, userID, archived)
}

func (s *ExpenseService) DeletePerson(ctx context.Context, userID, id string) error {
	shares, err := s.repo.CountPersonShares(ctx, id, userID)
	if err != nil {
		return fmt.Errorf("check shares: %w", err)
	}
	payments, err := s.repo.CountPersonPayments(ctx, id, userID)
	if err != nil {
		return fmt.Errorf("check payments: %w", err)
	}
	if shares > 0 || payments > 0 {
		return fmt.Errorf("person has history")
	}
	return s.repo.DeletePerson(ctx, id, userID)
}

func (s *ExpenseService) GetPersonShares(ctx context.Context, userID, personID, status string) ([]models.PersonShareExpense, error) {
	if _, err := s.repo.GetPersonByID(ctx, personID, userID); err != nil {
		return nil, err
	}
	return s.repo.GetSharesByPerson(ctx, personID, userID, status)
}

func (s *ExpenseService) CreatePersonPayment(ctx context.Context, userID, personID string, amount float64, paidAt, note string) (*models.PersonPayment, error) {
	if amount <= 0 {
		return nil, fmt.Errorf("amount must be greater than zero")
	}
	if paidAt == "" {
		paidAt = time.Now().Format("2006-01-02")
	} else if _, err := time.Parse("2006-01-02", paidAt); err != nil {
		return nil, fmt.Errorf("invalid paid_at date")
	}
	if _, err := s.repo.GetPersonByID(ctx, personID, userID); err != nil {
		return nil, err
	}
	return s.repo.CreatePersonPayment(ctx, personID, userID, amount, paidAt, note)
}

func (s *ExpenseService) DeletePersonPayment(ctx context.Context, userID, id string) error {
	return s.repo.DeletePersonPayment(ctx, id, userID)
}

func (s *ExpenseService) ListPersonPayments(ctx context.Context, userID, personID string) ([]models.PersonPayment, error) {
	if _, err := s.repo.GetPersonByID(ctx, personID, userID); err != nil {
		return nil, err
	}
	return s.repo.ListPersonPayments(ctx, personID, userID)
}

func (s *ExpenseService) GetSharedSummary(ctx context.Context, userID string) (*models.SharedSummary, error) {
	return s.repo.GetSharedSummary(ctx, userID)
}

// validatePresetRefs verifica que category_id/card_id del preset pertenezcan al
// usuario autenticado (mismo patrón anti-IDOR que validateExpenseRefs).
func (s *ExpenseService) validatePresetRefs(ctx context.Context, userID, categoryID string, cardID *string) error {
	if categoryID != "" {
		if _, err := s.repo.GetCategoryByID(ctx, categoryID, userID); err != nil {
			return fmt.Errorf("category not found: %w", err)
		}
	}
	if cardID != nil && *cardID != "" {
		if _, err := s.repo.GetCardByID(ctx, *cardID, userID); err != nil {
			return fmt.Errorf("card not found: %w", err)
		}
	}
	return nil
}

// extForContentType mapea el contentType (ya validado por magic bytes en el
// handler vía http.DetectContentType) a una extensión de archivo segura.
// Si el tipo no está en la lista, usa fallback — nunca se confía en el
// Content-Type enviado por el cliente.
func extForContentType(contentType, fallback string) string {
	switch contentType {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "audio/mpeg":
		return ".mp3"
	case "audio/wave", "audio/x-wav":
		return ".wav"
	case "audio/ogg", "application/ogg", "video/ogg":
		return ".ogg"
	default:
		return fallback
	}
}

func normalizeFranchise(franchise string) string {
	franchise = strings.ToLower(strings.TrimSpace(franchise))
	switch franchise {
	case "visa", "mastercard", "amex", "diners":
		return franchise
	default:
		return "other"
	}
}
