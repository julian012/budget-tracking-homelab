package middleware

import (
	"encoding/base64"
	"fmt"
	"testing"
	"time"
)

func TestTokenCache_MissOnEmpty(t *testing.T) {
	c := newTokenCache()
	if _, ok := c.get("token"); ok {
		t.Fatal("esperaba miss en cache vacía")
	}
}

func TestTokenCache_HitAfterSet(t *testing.T) {
	c := newTokenCache()
	c.set("token", "uid-1", time.Minute)

	uid, ok := c.get("token")
	if !ok {
		t.Fatal("esperaba hit")
	}
	if uid != "uid-1" {
		t.Fatalf("uid = %q, want %q", uid, "uid-1")
	}
}

func TestTokenCache_ExpiresAfterTTL(t *testing.T) {
	c := newTokenCache()
	c.set("token", "uid-1", time.Millisecond)

	time.Sleep(5 * time.Millisecond)

	if _, ok := c.get("token"); ok {
		t.Fatal("esperaba miss tras expirar el TTL")
	}
}

func TestTokenCache_DoesNotSetWithZeroTTL(t *testing.T) {
	c := newTokenCache()
	c.set("token", "uid-1", 0)

	if _, ok := c.get("token"); ok {
		t.Fatal("no debería cachearse una entrada con ttl <= 0")
	}
}

func TestJwtExpiry_ValidToken(t *testing.T) {
	exp := time.Now().Add(30 * time.Minute).Unix()
	token := fmt.Sprintf("header.%s.sig", base64URL(exp))

	if got := jwtExpiry(token); got != exp {
		t.Fatalf("jwtExpiry = %d, want %d", got, exp)
	}
}

func TestJwtExpiry_InvalidToken(t *testing.T) {
	for _, token := range []string{"", "no-dots", "a.b", "not-json.@@@@.sig"} {
		if got := jwtExpiry(token); got != 0 {
			t.Fatalf("jwtExpiry(%q) = %d, want 0", token, got)
		}
	}
}

// base64URL construye el segmento payload (con el claim `exp`) de un JWT de
// prueba, codificado en base64url sin padding, igual que un token real.
func base64URL(exp int64) string {
	payload := fmt.Sprintf(`{"exp":%d}`, exp)
	return base64.RawURLEncoding.EncodeToString([]byte(payload))
}
