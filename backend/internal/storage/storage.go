package storage

import (
	"context"
	"fmt"
	"io"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type MinioClient struct {
	client *minio.Client
	bucket string
}

func NewMinioClient(endpoint, accessKey, secretKey string, useSSL bool) (*MinioClient, error) {
	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(accessKey, secretKey, ""),
		Secure: useSSL,
	})
	if err != nil {
		return nil, fmt.Errorf("minio client: %w", err)
	}
	return &MinioClient{client: client, bucket: "receipts"}, nil
}

func (m *MinioClient) EnsureBuckets(ctx context.Context) error {
	buckets := []string{"receipts", "audio"}
	for _, b := range buckets {
		exists, err := m.client.BucketExists(ctx, b)
		if err != nil {
			return fmt.Errorf("check bucket %s: %w", b, err)
		}
		if !exists {
			if err := m.client.MakeBucket(ctx, b, minio.MakeBucketOptions{}); err != nil {
				return fmt.Errorf("create bucket %s: %w", b, err)
			}
		}
	}
	return nil
}

func (m *MinioClient) UploadReceipt(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	_, err := m.client.PutObject(ctx, "receipts", objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("upload receipt: %w", err)
	}
	return fmt.Sprintf("receipts/%s", objectName), nil
}

func (m *MinioClient) UploadAudio(ctx context.Context, objectName string, reader io.Reader, size int64, contentType string) (string, error) {
	_, err := m.client.PutObject(ctx, "audio", objectName, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("upload audio: %w", err)
	}
	return fmt.Sprintf("audio/%s", objectName), nil
}
