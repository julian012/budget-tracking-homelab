package middleware

import (
	"encoding/base64"
	"encoding/json"
	"strings"
	"sync"
	"time"
)

// maxTokenCacheTTL acota cuánto se cachea un ID token verificado. Los tokens
// de Firebase duran ~1h, así que nunca se cachea más de esa ventana.
const maxTokenCacheTTL = time.Hour

// tokenCache cachea el resultado de verificar un ID token de Firebase
// (token -> localId) en memoria. El TTL de cada entrada se acota por el
// claim `exp` del propio JWT, para no confiar en un token más allá de su
// validez real. El acceso es thread-safe.
type tokenCache struct {
	mu   sync.Mutex
	data map[string]tokenCacheEntry
}

type tokenCacheEntry struct {
	uid     string
	expires time.Time
}

func newTokenCache() *tokenCache {
	return &tokenCache{data: make(map[string]tokenCacheEntry)}
}

// get devuelve el uid cacheado si la entrada existe y no expiró. Las entradas
// vencidas se eliminan de forma perezosa al consultarlas.
func (c *tokenCache) get(token string) (string, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	e, ok := c.data[token]
	if !ok {
		return "", false
	}
	if time.Now().After(e.expires) {
		delete(c.data, token)
		return "", false
	}
	return e.uid, true
}

// set guarda el resultado con un TTL acotado. Si ttl <= 0 no se cachea (por
// ejemplo, un token ya vencido o sin claim `exp` legible).
func (c *tokenCache) set(token, uid string, ttl time.Duration) {
	if ttl <= 0 {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.data[token] = tokenCacheEntry{uid: uid, expires: time.Now().Add(ttl)}
}

// jwtExpiry extrae el claim `exp` (unix seconds) de un JWT **sin verificar la
// firma**. Se usa únicamente para acotar el TTL de la caché, no como
// validación de seguridad (la verificación real la hace el proveedor).
func jwtExpiry(token string) int64 {
	parts := strings.Split(token, ".")
	if len(parts) < 2 {
		return 0
	}
	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return 0
	}
	var claims struct {
		Exp int64 `json:"exp"`
	}
	if err := json.Unmarshal(payload, &claims); err != nil {
		return 0
	}
	return claims.Exp
}
