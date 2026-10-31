package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORS_AllowsKnownOrigin(t *testing.T) {
	nextCalled := false
	handler := CORS([]string{"https://api.example.com"})(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nextCalled = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/expenses", nil)
	req.Header.Set("Origin", "https://api.example.com")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if !nextCalled {
		t.Fatal("esperaba que se llamara al siguiente handler")
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "https://api.example.com" {
		t.Errorf("Access-Control-Allow-Origin = %q, want el origen conocido", got)
	}
	if got := rec.Header().Get("Access-Control-Allow-Methods"); got == "" {
		t.Error("esperaba Access-Control-Allow-Methods seteado")
	}
	if got := rec.Header().Get("Access-Control-Allow-Headers"); got == "" {
		t.Error("esperaba Access-Control-Allow-Headers seteado")
	}
}

func TestCORS_DoesNotReflectUnknownOrigin(t *testing.T) {
	handler := CORS([]string{"https://api.example.com"})(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/expenses", nil)
	req.Header.Set("Origin", "https://evil.example.com")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("Access-Control-Allow-Origin = %q, esperaba vacío para un origen no permitido", got)
	}
}

func TestCORS_NoOriginHeaderStillCallsNext(t *testing.T) {
	// Requests sin header Origin (ej. la app móvil nativa, curl, MCP server)
	// no están sujetas a CORS y deben seguir funcionando sin el header
	// Access-Control-Allow-Origin en la respuesta.
	nextCalled := false
	handler := CORS([]string{"https://api.example.com"})(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nextCalled = true
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest(http.MethodGet, "/api/expenses", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if !nextCalled {
		t.Fatal("esperaba que se llamara al siguiente handler sin header Origin")
	}
	if got := rec.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Errorf("Access-Control-Allow-Origin = %q, esperaba vacío sin header Origin", got)
	}
}

func TestCORS_ShortCircuitsPreflight(t *testing.T) {
	nextCalled := false
	handler := CORS([]string{"https://api.example.com"})(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		nextCalled = true
	}))

	req := httptest.NewRequest(http.MethodOptions, "/api/expenses", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if nextCalled {
		t.Fatal("un preflight OPTIONS no debería llegar al siguiente handler")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusOK)
	}
}
