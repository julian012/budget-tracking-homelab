package config

import (
	"log"
	"os"
	"strings"
)

// sensitiveDefaults son env vars cuyo fallback hardcodeado es solo para dev
// local. Si en producción se omiten por accidente, el backend arrancaría con
// credenciales débiles — se loguea una WARN visible para detectarlo.
var sensitiveDefaults = map[string]bool{
	"DATABASE_URL":     true,
	"MINIO_ACCESS_KEY": true,
	"MINIO_SECRET_KEY": true,
	"MINIO_ENDPOINT":   true,
}

type Config struct {
	DatabaseURL             string
	MinioEndpoint           string
	MinioAccessKey          string
	MinioSecretKey          string
	MinioUseSSL             bool
	FirebaseCredentialsPath string
	FirebaseWebAPIKey       string
	AllowDevAuth            bool
	AIApiKey                string
	AIApiEndpoint           string
	ServerPort              string
	AllowedOrigins          []string
}

func Load() *Config {
	return &Config{
		DatabaseURL:             getEnv("DATABASE_URL", "postgres://budget:change-me@localhost:5432/budget"),
		MinioEndpoint:           getEnv("MINIO_ENDPOINT", "localhost:9900"),
		MinioAccessKey:          getEnv("MINIO_ACCESS_KEY", "minioadmin"),
		MinioSecretKey:          getEnv("MINIO_SECRET_KEY", "change-me"),
		MinioUseSSL:             getEnv("MINIO_USE_SSL", "false") == "true",
		FirebaseCredentialsPath: getEnv("FIREBASE_CREDENTIALS_PATH", "firebase-service-account.json"),
		FirebaseWebAPIKey:       getEnv("FIREBASE_WEB_API_KEY", ""),
		AllowDevAuth:            getEnv("ALLOW_DEV_AUTH", "false") == "true",
		AIApiKey:                getEnv("AI_API_KEY", ""),
		AIApiEndpoint:           getEnv("AI_API_ENDPOINT", "https://opencode.ai/zen/go/v1"),
		ServerPort:              getEnv("SERVER_PORT", "4000"),
		AllowedOrigins:          getEnvList("ALLOWED_ORIGINS", "http://localhost:4000"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	if sensitiveDefaults[key] {
		log.Printf("WARN config: %s no está definida — usando fallback SOLO apto para dev local; definila explícitamente en producción", key)
	}
	return fallback
}

// getEnvList lee una lista separada por comas (ej. "https://a.com,https://b.com").
func getEnvList(key, fallback string) []string {
	return strings.Split(getEnv(key, fallback), ",")
}
