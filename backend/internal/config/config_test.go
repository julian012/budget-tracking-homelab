package config

import "testing"

func TestLoad_Defaults(t *testing.T) {
	cfg := Load()

	if cfg.MinioEndpoint != "localhost:9900" {
		t.Errorf("MinioEndpoint = %q, want %q", cfg.MinioEndpoint, "localhost:9900")
	}
	if cfg.MinioUseSSL {
		t.Error("MinioUseSSL default debería ser false")
	}
	if cfg.AllowDevAuth {
		t.Error("AllowDevAuth default debería ser false (fail-closed)")
	}
	if cfg.ServerPort != "4000" {
		t.Errorf("ServerPort = %q, want %q", cfg.ServerPort, "4000")
	}
	if cfg.FirebaseWebAPIKey != "" {
		t.Errorf("FirebaseWebAPIKey default debería ser vacío, got %q", cfg.FirebaseWebAPIKey)
	}
	if len(cfg.AllowedOrigins) != 1 || cfg.AllowedOrigins[0] != "http://localhost:4000" {
		t.Errorf("AllowedOrigins = %v, want [http://localhost:4000]", cfg.AllowedOrigins)
	}
}

func TestLoad_EnvOverrides(t *testing.T) {
	t.Setenv("MINIO_USE_SSL", "true")
	t.Setenv("ALLOW_DEV_AUTH", "true")
	t.Setenv("SERVER_PORT", "9999")
	t.Setenv("DATABASE_URL", "postgres://custom/db")

	cfg := Load()

	if !cfg.MinioUseSSL {
		t.Error("MinioUseSSL debería ser true con MINIO_USE_SSL=true")
	}
	if !cfg.AllowDevAuth {
		t.Error("AllowDevAuth debería ser true con ALLOW_DEV_AUTH=true")
	}
	if cfg.ServerPort != "9999" {
		t.Errorf("ServerPort = %q, want %q", cfg.ServerPort, "9999")
	}
	if cfg.DatabaseURL != "postgres://custom/db" {
		t.Errorf("DatabaseURL = %q, want %q", cfg.DatabaseURL, "postgres://custom/db")
	}
}

func TestLoad_AllowDevAuthRequiresExactTrue(t *testing.T) {
	t.Setenv("ALLOW_DEV_AUTH", "1")
	cfg := Load()
	if cfg.AllowDevAuth {
		t.Error(`AllowDevAuth solo debería activarse con el string exacto "true", no "1" — evita habilitarlo por accidente`)
	}
}

func TestLoad_AllowedOriginsParsesCommaSeparatedList(t *testing.T) {
	t.Setenv("ALLOWED_ORIGINS", "https://a.example.com,https://b.example.com")
	cfg := Load()
	want := []string{"https://a.example.com", "https://b.example.com"}
	if len(cfg.AllowedOrigins) != len(want) {
		t.Fatalf("AllowedOrigins = %v, want %v", cfg.AllowedOrigins, want)
	}
	for i, o := range want {
		if cfg.AllowedOrigins[i] != o {
			t.Errorf("AllowedOrigins[%d] = %q, want %q", i, cfg.AllowedOrigins[i], o)
		}
	}
}
