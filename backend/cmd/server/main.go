package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/example/budget-tracking-homelab/backend/internal/config"
	"github.com/example/budget-tracking-homelab/backend/internal/handler"
	"github.com/example/budget-tracking-homelab/backend/internal/middleware"
	"github.com/example/budget-tracking-homelab/backend/internal/repository"
	"github.com/example/budget-tracking-homelab/backend/internal/service"
	"github.com/example/budget-tracking-homelab/backend/internal/storage"
	"github.com/example/budget-tracking-homelab/backend/migrations"

	"github.com/go-chi/chi/v5"
)

func main() {
	cfg := config.Load()

	repo, err := repository.NewPostgresRepo(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("database connection: %v", err)
	}
	defer repo.Close()

	if err := migrations.Run(context.Background(), repo.Pool()); err != nil {
		log.Fatalf("run migrations: %v", err)
	}

	minioClient, err := storage.NewMinioClient(cfg.MinioEndpoint, cfg.MinioAccessKey, cfg.MinioSecretKey, cfg.MinioUseSSL)
	if err != nil {
		log.Fatalf("minio client: %v", err)
	}

	if err := minioClient.EnsureBuckets(context.Background()); err != nil {
		log.Printf("warning: ensure buckets: %v", err)
	}

	svc := service.NewExpenseService(repo, minioClient, cfg.AIApiEndpoint, cfg.AIApiKey)

	auth := middleware.NewFirebaseAuth(cfg.FirebaseWebAPIKey, cfg.AllowDevAuth, repo)
	expenseHandler := handler.NewExpenseHandler(svc)

	r := chi.NewRouter()
	r.Use(middleware.CORS(cfg.AllowedOrigins))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Group(func(r chi.Router) {
		r.Use(auth.Authenticate)
		expenseHandler.RegisterRoutes(r)
	})

	srv := &http.Server{
		Addr:         fmt.Sprintf(":%s", cfg.ServerPort),
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("server starting on :%s", cfg.ServerPort)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("shutdown error: %v", err)
	}
	log.Println("server stopped")
}
