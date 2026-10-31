package service

import (
	"context"
	"errors"
	"io"
	"strings"
	"testing"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
	"github.com/example/budget-tracking-homelab/backend/internal/repository"
)

// fakeExpenseRepo implementa repository.ExpenseRepo embebiendo la interfaz
// (queda nil) y sobreescribiendo solo los métodos que ejercitan estos tests.
// Cualquier otro método panicaría si se llegara a invocar, lo cual está bien
// para probar CreateExpense/UpdateExpense de forma aislada.
type fakeExpenseRepo struct {
	repository.ExpenseRepo
	categories    map[string]string // categoryID -> userID dueño
	cards         map[string]string // cardID -> userID dueño
	saved         *models.Expense
	usersByUID    map[string]*models.User
	createCalled  bool
	categoryList  []models.Category
	updatedCat    *models.Category
	presets       map[string]string // presetID -> userID dueño
	createdPreset *models.Preset
	updatedPreset *models.Preset
	deletedPreset string
}

func (f *fakeExpenseRepo) GetCategoryByID(ctx context.Context, id, userID string) (*models.Category, error) {
	owner, ok := f.categories[id]
	if !ok || owner != userID {
		return nil, errors.New("category not found")
	}
	return &models.Category{ID: id, UserID: userID}, nil
}

func (f *fakeExpenseRepo) GetCardByID(ctx context.Context, id, userID string) (*models.Card, error) {
	owner, ok := f.cards[id]
	if !ok || owner != userID {
		return nil, errors.New("card not found")
	}
	return &models.Card{ID: id, UserID: userID}, nil
}

func (f *fakeExpenseRepo) Create(ctx context.Context, expense *models.Expense) error {
	expense.ID = "new-expense-id"
	f.saved = expense
	return nil
}

func (f *fakeExpenseRepo) UpdateExpense(ctx context.Context, expense *models.Expense) error {
	f.saved = expense
	return nil
}

func (f *fakeExpenseRepo) GetExpenseByID(ctx context.Context, id, userID string) (*models.Expense, error) {
	return f.saved, nil
}

func (f *fakeExpenseRepo) GetUserByFirebaseUID(ctx context.Context, uid string) (*models.User, error) {
	u, ok := f.usersByUID[uid]
	if !ok {
		return nil, errors.New("user not found")
	}
	return u, nil
}

func (f *fakeExpenseRepo) CreateUser(ctx context.Context, user *models.User) error {
	f.createCalled = true
	user.ID = "new-user-id"
	if f.usersByUID == nil {
		f.usersByUID = map[string]*models.User{}
	}
	f.usersByUID[user.FirebaseUID] = user
	return nil
}

// GetCategories replica el scoping por userID de la query real
// (WHERE user_id=$1) — sin esto, un test que ponga una categoría de
// "otro-usuario" en categoryList pasaría de largo el chequeo de ownership
// que en producción hace el propio WHERE de la query, no el loop de arriba.
func (f *fakeExpenseRepo) GetCategories(ctx context.Context, userID string) ([]models.Category, error) {
	var result []models.Category
	for _, c := range f.categoryList {
		if c.UserID == userID {
			result = append(result, c)
		}
	}
	return result, nil
}

func (f *fakeExpenseRepo) UpdateCategory(ctx context.Context, category *models.Category) error {
	f.updatedCat = category
	return nil
}

func (f *fakeExpenseRepo) GetPresetByID(ctx context.Context, id, userID string) (*models.Preset, error) {
	owner, ok := f.presets[id]
	if !ok || owner != userID {
		return nil, errors.New("preset not found")
	}
	return &models.Preset{ID: id, UserID: userID}, nil
}

func (f *fakeExpenseRepo) CreatePreset(ctx context.Context, preset *models.Preset) error {
	preset.ID = "new-preset-id"
	f.createdPreset = preset
	return nil
}

func (f *fakeExpenseRepo) UpdatePreset(ctx context.Context, preset *models.Preset) error {
	f.updatedPreset = preset
	return nil
}

func (f *fakeExpenseRepo) DeletePreset(ctx context.Context, id, userID string) error {
	f.deletedPreset = id
	return nil
}

func TestCreatePreset_RejectsCategoryFromAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{categories: map[string]string{"cat-1": "other-user"}}
	svc := NewExpenseService(repo, nil, "", "")

	_, err := svc.CreatePreset(context.Background(), "me", models.PresetInput{
		Name: "Flota", CategoryID: "cat-1", Amount: 12000,
	})
	if err == nil {
		t.Fatal("esperaba error al crear un preset con category_id de otro usuario")
	}
	if repo.createdPreset != nil {
		t.Fatal("no debería haber persistido el preset")
	}
}

func TestCreatePreset_RejectsCardFromAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{
		categories: map[string]string{"cat-1": "me"},
		cards:      map[string]string{"card-1": "other-user"},
	}
	svc := NewExpenseService(repo, nil, "", "")

	cardID := "card-1"
	_, err := svc.CreatePreset(context.Background(), "me", models.PresetInput{
		Name: "Flota", CategoryID: "cat-1", CardID: &cardID, Amount: 12000,
	})
	if err == nil {
		t.Fatal("esperaba error al crear un preset con card_id de otro usuario")
	}
	if repo.createdPreset != nil {
		t.Fatal("no debería haber persistido el preset")
	}
}

func TestCreatePreset_RequiresName(t *testing.T) {
	repo := &fakeExpenseRepo{categories: map[string]string{"cat-1": "me"}}
	svc := NewExpenseService(repo, nil, "", "")

	_, err := svc.CreatePreset(context.Background(), "me", models.PresetInput{Name: "  ", CategoryID: "cat-1", Amount: 12000})
	if err == nil {
		t.Fatal("esperaba error con nombre vacío")
	}
	if repo.createdPreset != nil {
		t.Fatal("no debería haber persistido el preset")
	}
}

func TestCreatePreset_AllowsOwnCategoryAndCard(t *testing.T) {
	repo := &fakeExpenseRepo{
		categories: map[string]string{"cat-1": "me"},
		cards:      map[string]string{"card-1": "me"},
	}
	svc := NewExpenseService(repo, nil, "", "")

	cardID := "card-1"
	preset, err := svc.CreatePreset(context.Background(), "me", models.PresetInput{
		Name: "Flota Tunja-Bogotá", CategoryID: "cat-1", CardID: &cardID, Amount: 25000, Description: "pasajes",
	})
	if err != nil {
		t.Fatalf("no esperaba error: %v", err)
	}
	if preset.ID == "" {
		t.Fatal("esperaba que el preset quedara persistido")
	}
	if repo.createdPreset.CardID == nil || *repo.createdPreset.CardID != cardID {
		t.Errorf("CardID = %v, want %q", repo.createdPreset.CardID, cardID)
	}
}

func TestUpdatePreset_RejectsCategoryFromAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{
		categories: map[string]string{"cat-1": "other-user"},
		presets:    map[string]string{"preset-1": "me"},
	}
	svc := NewExpenseService(repo, nil, "", "")

	_, err := svc.UpdatePreset(context.Background(), "me", "preset-1", models.PresetInput{Name: "x", CategoryID: "cat-1", Amount: 1})
	if err == nil {
		t.Fatal("esperaba error al actualizar un preset con category_id de otro usuario")
	}
	if repo.updatedPreset != nil {
		t.Fatal("no debería haber actualizado el preset")
	}
}

func TestCreateExpense_RejectsCategoryFromAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{categories: map[string]string{"cat-1": "other-user"}}
	svc := NewExpenseService(repo, nil, "", "")

	_, err := svc.CreateExpense(context.Background(), "me", models.ExpenseInput{
		CategoryID:  "cat-1",
		Amount:      100,
		ExpenseDate: "2026-08-25",
	})
	if err == nil {
		t.Fatal("esperaba error al crear un gasto con category_id de otro usuario")
	}
	if repo.saved != nil {
		t.Fatal("no debería haber persistido el gasto")
	}
}

func TestCreateExpense_RejectsCardFromAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{
		categories: map[string]string{"cat-1": "me"},
		cards:      map[string]string{"card-1": "other-user"},
	}
	svc := NewExpenseService(repo, nil, "", "")

	cardID := "card-1"
	_, err := svc.CreateExpense(context.Background(), "me", models.ExpenseInput{
		CategoryID:  "cat-1",
		CardID:      &cardID,
		Amount:      100,
		ExpenseDate: "2026-08-25",
	})
	if err == nil {
		t.Fatal("esperaba error al crear un gasto con card_id de otro usuario")
	}
	if repo.saved != nil {
		t.Fatal("no debería haber persistido el gasto")
	}
}

func TestCreateExpense_AllowsOwnCategoryAndCard(t *testing.T) {
	repo := &fakeExpenseRepo{
		categories: map[string]string{"cat-1": "me"},
		cards:      map[string]string{"card-1": "me"},
	}
	svc := NewExpenseService(repo, nil, "", "")

	cardID := "card-1"
	expense, err := svc.CreateExpense(context.Background(), "me", models.ExpenseInput{
		CategoryID:  "cat-1",
		CardID:      &cardID,
		Amount:      100,
		ExpenseDate: "2026-08-25",
	})
	if err != nil {
		t.Fatalf("no esperaba error: %v", err)
	}
	if expense.ID == "" {
		t.Fatal("esperaba que el gasto quedara persistido")
	}
}

func TestUpdateExpense_RejectsCategoryFromAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{categories: map[string]string{"cat-1": "other-user"}}
	svc := NewExpenseService(repo, nil, "", "")

	_, err := svc.UpdateExpense(context.Background(), "me", "expense-1", models.ExpenseInput{
		CategoryID:  "cat-1",
		Amount:      100,
		ExpenseDate: "2026-08-25",
	})
	if err == nil {
		t.Fatal("esperaba error al actualizar un gasto con category_id de otro usuario")
	}
	if repo.saved != nil {
		t.Fatal("no debería haber actualizado el gasto")
	}
}

func TestUpdateCategory_NotFoundForAnotherUser(t *testing.T) {
	repo := &fakeExpenseRepo{categoryList: []models.Category{
		{ID: "cat-1", UserID: "otro-usuario", Name: "vieja"},
	}}
	svc := NewExpenseService(repo, nil, "", "")

	_, err := svc.UpdateCategory(context.Background(), "me", "cat-1", models.CategoryUpdateInput{Name: "nueva"})
	if err == nil {
		t.Fatal("esperaba error: cat-1 no está en la lista de categorías de 'me'")
	}
	if repo.updatedCat != nil {
		t.Fatal("no debería haber actualizado la categoría")
	}
}

func TestUpdateCategory_UpdatesOwnCategory(t *testing.T) {
	repo := &fakeExpenseRepo{categoryList: []models.Category{
		{ID: "cat-1", UserID: "me", Name: "vieja"},
	}}
	svc := NewExpenseService(repo, nil, "", "")

	updated, err := svc.UpdateCategory(context.Background(), "me", "cat-1", models.CategoryUpdateInput{Name: "nueva", Color: "#FFFFFF"})
	if err != nil {
		t.Fatalf("no esperaba error: %v", err)
	}
	if updated.Name != "nueva" {
		t.Errorf("Name = %q, want %q", updated.Name, "nueva")
	}
	if repo.updatedCat == nil {
		t.Fatal("esperaba que se llamara a UpdateCategory")
	}
}

func TestNormalizeFranchise(t *testing.T) {
	cases := map[string]string{
		"visa":       "visa",
		"MASTERCARD": "mastercard",
		" Amex ":     "amex",
		"diners":     "diners",
		"":           "other",
		"discover":   "other",
	}
	for input, want := range cases {
		if got := normalizeFranchise(input); got != want {
			t.Errorf("normalizeFranchise(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestExtractJSON(t *testing.T) {
	cases := map[string]string{
		`{"a":1}`:                 `{"a":1}`,
		"```json\n{\"a\":1}\n```": `{"a":1}`,
		"Aquí tienes: {\"a\":1} — eso es todo": `{"a":1}`,
		"sin json aquí": "sin json aquí",
	}
	for input, want := range cases {
		if got := extractJSON(input); got != want {
			t.Errorf("extractJSON(%q) = %q, want %q", input, got, want)
		}
	}
}

// fakeUploader captura el objectName que el service genera a partir del
// contentType real detectado (magic bytes en el handler), para probar el
// mapeo extensión-contenido (#47) sin necesidad de un MinIO.
type fakeUploader struct {
	receiptName string
	audioName   string
	receiptErr  error
	audioErr    error
}

func (f *fakeUploader) EnsureBuckets(ctx context.Context) error { return nil }

func (f *fakeUploader) UploadReceipt(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	if f.receiptErr != nil {
		return "", f.receiptErr
	}
	f.receiptName = objectName
	return "receipts/" + objectName, nil
}

func (f *fakeUploader) UploadAudio(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	if f.audioErr != nil {
		return "", f.audioErr
	}
	f.audioName = objectName
	return "audio/" + objectName, nil
}

func TestProcessReceipt_ExtensionMatchesContentType(t *testing.T) {
	cases := map[string]string{
		"image/jpeg": ".jpg",
		"image/png":  ".png",
	}
	for contentType, wantExt := range cases {
		up := &fakeUploader{}
		svc := NewExpenseService(&fakeExpenseRepo{}, up, "", "")
		_, err := svc.ProcessReceipt(context.Background(), "me", []byte("x"), contentType)
		if err != nil {
			t.Fatalf("ProcessReceipt(%s): %v", contentType, err)
		}
		if !strings.HasSuffix(up.receiptName, wantExt) {
			t.Errorf("contentType %q -> objectName %q, want sufijo %q", contentType, up.receiptName, wantExt)
		}
	}
}

func TestProcessReceipt_UploadErrorPropagates(t *testing.T) {
	up := &fakeUploader{receiptErr: errors.New("minio down")}
	svc := NewExpenseService(&fakeExpenseRepo{}, up, "", "")
	if _, err := svc.ProcessReceipt(context.Background(), "me", []byte("x"), "image/jpeg"); err == nil {
		t.Fatal("esperaba error cuando el upload falla")
	}
}

func TestProcessVoice_ExtensionMatchesContentType(t *testing.T) {
	cases := map[string]string{
		"audio/mpeg":      ".mp3",
		"audio/wave":      ".wav",
		"audio/x-wav":     ".wav",
		"audio/ogg":       ".ogg",
		"application/ogg": ".ogg",
		"video/ogg":       ".ogg",
	}
	for contentType, wantExt := range cases {
		up := &fakeUploader{}
		svc := NewExpenseService(&fakeExpenseRepo{}, up, "", "")
		if _, err := svc.ProcessVoice(context.Background(), "me", []byte("x"), contentType); err != nil {
			t.Fatalf("ProcessVoice(%s): %v", contentType, err)
		}
		if !strings.HasSuffix(up.audioName, wantExt) {
			t.Errorf("contentType %q -> objectName %q, want sufijo %q", contentType, up.audioName, wantExt)
		}
	}
}

func TestExtForContentType(t *testing.T) {
	if got := extForContentType("application/zip", ".bin"); got != ".bin" {
		t.Errorf("extForContentType desconocido = %q, want .bin", got)
	}
}
