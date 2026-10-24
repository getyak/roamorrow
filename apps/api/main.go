package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/getyak/solo-compass/api/internal/harness"
	"github.com/getyak/solo-compass/api/internal/reviews"
	"github.com/getyak/solo-compass/api/migrate"
	"github.com/gin-gonic/gin"
)

func main() {
	db, err := reviews.OpenDB(os.Getenv("DATABASE_URL"))
	if err != nil {
		log.Printf("warn: database unavailable (%v) — /v1 endpoints will return 503", err)
	}

	cfg, err := harness.LoadConfig()
	if err != nil {
		log.Fatalf("harness config: %v", err)
	}

	// Harness private database: separate from DATABASE_URL so this service
	// never reuses another application's database. Migrations live in the
	// runtime image (apps/api/migrations/harness) and are idempotent.
	if len(os.Args) > 1 && os.Args[1] == "migrate" {
		hdb, err := harness.OpenHarnessDB(cfg.DatabaseDSN)
		if err != nil {
			log.Fatalf("harness database: %v", err)
		}
		if err := migrate.Run(hdb, cfg.MigrationsDir); err != nil {
			log.Fatalf("harness migrations failed: %v", err)
		}
		log.Printf("harness migrations applied")
		return
	}

	var store harness.Store
	if cfg.DatabaseDSN != "" {
		hdb, err := harness.OpenHarnessDB(cfg.DatabaseDSN)
		if err != nil {
			log.Printf("warn: harness database unavailable (%v) — harness endpoints will return 503", err)
		} else {
			if err := migrate.Run(hdb, cfg.MigrationsDir); err != nil {
				log.Fatalf("harness migrations failed: %v", err)
			}
			store = harness.NewPostgresStore(hdb)
		}
	}

	srv := harness.NewServer(cfg, store)

	r := gin.New()
	// Query-free access log + request-dump-free recovery: OAuth callback codes
	// and states must never reach logs (gin.Default() would leak them).
	r.Use(harness.NewLogger(os.Stdout), harness.NewRecovery(os.Stdout))

	// Health check — always available, no DB dependency.
	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	// v1 API — requires database.
	v1 := r.Group("/v1")
	{
		v1.GET("/experiences/:id/solo-score", func(c *gin.Context) {
			if db == nil {
				c.JSON(http.StatusServiceUnavailable, gin.H{"error": "database unavailable"})
				return
			}
			reviews.HandleGetSoloScore(c, db)
		})
	}

	// DeepSeek onboarding harness (frozen wire contract):
	// /v1/harness/* + /mcp.
	srv.Register(r)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	httpSrv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      180 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Printf("listening on :%s", port)
	if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server failed: %v", err)
	}
	// Graceful drain is best-effort; the harness compose runtime is a test
	// runtime with restart=no and no release semantics.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(ctx)
}
