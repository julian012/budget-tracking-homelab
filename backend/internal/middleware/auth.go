package middleware

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/models"
)

type contextKey string

const UserIDKey contextKey = "userID"

// UserRepo is the minimal subset of repository.ExpenseRepo that auth needs,
// declarado aparte para poder testear Authenticate/verifyToken con un fake
// sin tener que implementar la interfaz completa de repository.ExpenseRepo.
type UserRepo interface {
	GetUserByFirebaseUID(ctx context.Context, uid string) (*models.User, error)
	CreateUser(ctx context.Context, user *models.User) error
}

type FirebaseAuth struct {
	webAPIKey    string
	allowDevAuth bool
	repo         UserRepo
	cache        *tokenCache
}

func NewFirebaseAuth(webAPIKey string, allowDevAuth bool, repo UserRepo) *FirebaseAuth {
	return &FirebaseAuth{webAPIKey: webAPIKey, allowDevAuth: allowDevAuth, repo: repo, cache: newTokenCache()}
}

func (a *FirebaseAuth) Authenticate(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
			return
		}

		token := strings.TrimPrefix(authHeader, "Bearer ")

		firebaseUID, err := a.verifyToken(r.Context(), token)
		if err != nil {
			http.Error(w, `{"error":"invalid token"}`, http.StatusUnauthorized)
			return
		}

		dbUserID := firebaseUID
		if a.repo != nil {
			user, err := a.repo.GetUserByFirebaseUID(r.Context(), firebaseUID)
			if err != nil {
				user = &models.User{FirebaseUID: firebaseUID}
				if err := a.repo.CreateUser(r.Context(), user); err != nil {
					log.Printf("middleware: create user %s: %v", firebaseUID, err)
					http.Error(w, `{"error":"internal error"}`, http.StatusInternalServerError)
					return
				}
			}
			dbUserID = user.ID
		}

		ctx := context.WithValue(r.Context(), UserIDKey, dbUserID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func (a *FirebaseAuth) verifyToken(ctx context.Context, token string) (string, error) {
	if a.webAPIKey == "" {
		if a.allowDevAuth {
			return "dev-user-id", nil
		}
		return "", fmt.Errorf("auth: FIREBASE_WEB_API_KEY no configurada y ALLOW_DEV_AUTH no está habilitado")
	}

	// El SDK móvil reutiliza el mismo ID token durante ~1h, así que la verificación
	// contra Google se cachea en memoria (acotada por el claim `exp` del token)
	// para evitar ~250ms de llamada de red en cada request.
	if uid, ok := a.cache.get(token); ok {
		return uid, nil
	}

	reqBody, _ := json.Marshal(map[string]string{"idToken": token})
	url := "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + a.webAPIKey
	req, err := http.NewRequestWithContext(ctx, "POST", url, strings.NewReader(string(reqBody)))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var result struct {
		Users []struct {
			LocalID string `json:"localId"`
		} `json:"users"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", err
	}

	if len(result.Users) == 0 {
		return "", http.ErrNoCookie
	}

	uid := result.Users[0].LocalID
	ttl := time.Duration(jwtExpiry(token)-time.Now().Unix()) * time.Second
	if ttl > maxTokenCacheTTL {
		ttl = maxTokenCacheTTL
	}
	a.cache.set(token, uid, ttl)

	return uid, nil
}

func GetUserID(r *http.Request) string {
	uid, _ := r.Context().Value(UserIDKey).(string)
	return uid
}
