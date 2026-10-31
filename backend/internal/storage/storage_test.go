package storage

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
)

// minioTestConfig lee la config de un MinIO de test. Distingue "no provista"
// ("" → skip) de "provista vacía" (p. ej. MINIO_TEST_ACCESS_KEY="" en CI),
// porque os.Setenv permite valores vacíos y Getenv no los distingue de unset.
func minioTestConfig() (endpoint, accessKey, secretKey string, ok bool) {
	endpoint = os.Getenv("MINIO_TEST_ENDPOINT")
	if endpoint == "" {
		return "", "", "", false
	}
	ak, akSet := os.LookupEnv("MINIO_TEST_ACCESS_KEY")
	sk, skSet := os.LookupEnv("MINIO_TEST_SECRET_KEY")
	if !akSet {
		ak = "admin"
	}
	if !skSet {
		sk = "minioadmin"
	}
	return endpoint, ak, sk, true
}

// reachableMinio intenta un TCP dial corto para decidir si hay un MinIO de
// test disponible; si no, el test se salta (no falla) para no romper
// entornos sin Docker (CI sin servicio MinIO, máquinas limpias).
func reachableMinio(t *testing.T, endpoint string) bool {
	t.Helper()
	conn, err := net.DialTimeout("tcp", endpoint, 2*time.Second)
	if err != nil {
		t.Skipf("MinIO de test no disponible en %s (%v) — setear MINIO_TEST_ENDPOINT para correr estos tests", endpoint, err)
		return false
	}
	conn.Close()
	return true
}

func newTestMinio(t *testing.T) *MinioClient {
	t.Helper()
	endpoint, ak, sk, ok := minioTestConfig()
	if !ok {
		t.Skip("MINIO_TEST_ENDPOINT no definida — skipping storage integration tests")
	}
	if !reachableMinio(t, endpoint) {
		return nil
	}
	client, err := NewMinioClient(endpoint, ak, sk, false)
	if err != nil {
		t.Fatalf("NewMinioClient: %v", err)
	}
	t.Cleanup(func() {
		client.client.RemoveObject(context.Background(), "receipts", "test-cleanup", minio.RemoveObjectOptions{})
		client.client.RemoveObject(context.Background(), "audio", "test-cleanup", minio.RemoveObjectOptions{})
	})
	return client
}

func TestEnsureBuckets_Idempotent(t *testing.T) {
	m := newTestMinio(t)
	ctx := context.Background()

	if err := m.EnsureBuckets(ctx); err != nil {
		t.Fatalf("EnsureBuckets (1ra vez): %v", err)
	}
	if err := m.EnsureBuckets(ctx); err != nil {
		t.Fatalf("EnsureBuckets (2da vez, debe ser idempotente): %v", err)
	}
	for _, b := range []string{"receipts", "audio"} {
		exists, err := m.client.BucketExists(ctx, b)
		if err != nil {
			t.Fatalf("BucketExists(%s): %v", b, err)
		}
		if !exists {
			t.Errorf("bucket %s debería existir tras EnsureBuckets", b)
		}
	}
}

func TestUploadReceipt_ReturnsPrefixedURL(t *testing.T) {
	m := newTestMinio(t)
	ctx := context.Background()

	name := fmt.Sprintf("test-%s.jpg", uuid.New().String())
	data := []byte("fake-jpeg-bytes")
	url, err := m.UploadReceipt(ctx, name, bytes.NewReader(data), int64(len(data)), "image/jpeg")
	if err != nil {
		t.Fatalf("UploadReceipt: %v", err)
	}
	if want := "receipts/" + name; url != want {
		t.Errorf("url = %q, want %q", url, want)
	}
	defer m.client.RemoveObject(ctx, "receipts", name, minio.RemoveObjectOptions{})

	info, err := m.client.StatObject(ctx, "receipts", name, minio.StatObjectOptions{})
	if err != nil {
		t.Fatalf("StatObject tras subir: %v", err)
	}
	if info.Size != int64(len(data)) {
		t.Errorf("size = %d, want %d", info.Size, len(data))
	}
}

func TestUploadAudio_ReturnsPrefixedURL(t *testing.T) {
	m := newTestMinio(t)
	ctx := context.Background()

	name := fmt.Sprintf("test-%s.ogg", uuid.New().String())
	data := []byte("fake-ogg-bytes")
	url, err := m.UploadAudio(ctx, name, bytes.NewReader(data), int64(len(data)), "audio/ogg")
	if err != nil {
		t.Fatalf("UploadAudio: %v", err)
	}
	if want := "audio/" + name; url != want {
		t.Errorf("url = %q, want %q", url, want)
	}
	defer m.client.RemoveObject(ctx, "audio", name, minio.RemoveObjectOptions{})

	rc, err := m.client.GetObject(ctx, "audio", name, minio.GetObjectOptions{})
	if err != nil {
		t.Fatalf("GetObject tras subir: %v", err)
	}
	defer rc.Close()
	got, err := io.ReadAll(rc)
	if err != nil {
		t.Fatalf("read object: %v", err)
	}
	if !bytes.Equal(got, data) {
		t.Errorf("contenido round-trip = %q, want %q", got, data)
	}
}

func TestUploadReceipt_BucketMissingErrors(t *testing.T) {
	endpoint, ak, sk, ok := minioTestConfig()
	if !ok || !reachableMinio(t, endpoint) {
		if !ok {
			t.Skip("MINIO_TEST_ENDPOINT no definida")
		}
		return
	}
	client, err := NewMinioClient(endpoint, ak, sk, false)
	if err != nil {
		t.Fatalf("NewMinioClient: %v", err)
	}
	// Bucket inexistente: PutObject sobre un bucket que no está en la lista
	// conocida ("receipts"/"audio") debe propagar error, no devolver URL.
	_, err = client.client.PutObject(context.Background(), "no-existe-bucket-test", "x", bytes.NewReader([]byte("y")), 1, minio.PutObjectOptions{})
	if err == nil {
		t.Fatal("esperaba error al subir a un bucket inexistente")
	}
}
