package migrations

import (
	"context"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// TestRun_AppliesMigrationsAndIsIdempotent corre Run() contra una base de
// datos nueva y descartable (no budget_test, que ya tiene el esquema
// aplicado a mano vía psql en CI/local y no tiene schema_migrations). Esto
// es lo único que ejercita el migration runner embebido: CI aplica las
// migraciones con un loop de psql crudo, nunca llamando a Run().
func TestRun_AppliesMigrationsAndIsIdempotent(t *testing.T) {
	baseDSN := os.Getenv("TEST_DATABASE_URL")
	if baseDSN == "" {
		t.Fatal("TEST_DATABASE_URL es obligatoria; los tests NUNCA deben apuntar a la base de producción")
	}
	if !strings.Contains(baseDSN, "budget_test") {
		t.Fatalf("TEST_DATABASE_URL debe apuntar a budget_test, se obtuvo: %s", baseDSN)
	}

	u, err := url.Parse(baseDSN)
	if err != nil {
		t.Fatalf("parse TEST_DATABASE_URL: %v", err)
	}

	dbName := fmt.Sprintf("budget_migrations_test_%d", time.Now().UnixNano())

	ctx := context.Background()

	adminURL := *u
	adminURL.Path = "/postgres"
	adminPool, err := pgxpool.New(ctx, adminURL.String())
	if err != nil {
		t.Fatalf("connect to postgres maintenance db: %v", err)
	}
	defer adminPool.Close()

	if _, err := adminPool.Exec(ctx, fmt.Sprintf("CREATE DATABASE %s", dbName)); err != nil {
		t.Fatalf("create throwaway db: %v", err)
	}
	t.Cleanup(func() {
		adminPool.Exec(context.Background(), fmt.Sprintf("DROP DATABASE IF EXISTS %s", dbName))
	})

	testURL := *u
	testURL.Path = "/" + dbName
	pool, err := pgxpool.New(ctx, testURL.String())
	if err != nil {
		t.Fatalf("connect to throwaway db: %v", err)
	}
	defer pool.Close()

	if err := Run(ctx, pool); err != nil {
		t.Fatalf("Run (1ra vez): %v", err)
	}

	var tableCount int
	if err := pool.QueryRow(ctx,
		"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name IN ('users','categories','expenses','cards','presets','people','expense_shares','person_payments','payment_allocations')",
	).Scan(&tableCount); err != nil {
		t.Fatalf("check tables: %v", err)
	}
	if tableCount != 9 {
		t.Fatalf("esperaba 9 tablas (users, categories, expenses, cards, presets, people, expense_shares, person_payments, payment_allocations), encontré %d", tableCount)
	}

	// Debe ser idempotente: correrlo de nuevo no debe fallar ni reaplicar migraciones ya registradas.
	if err := Run(ctx, pool); err != nil {
		t.Fatalf("Run (2da vez, debería ser idempotente): %v", err)
	}

	var versionCount int
	if err := pool.QueryRow(ctx, "SELECT COUNT(*) FROM schema_migrations").Scan(&versionCount); err != nil {
		t.Fatalf("check schema_migrations: %v", err)
	}
	if versionCount == 0 {
		t.Fatal("esperaba versiones registradas en schema_migrations")
	}
}
