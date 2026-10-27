package harness

import (
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// NewLogger returns an access logger that is safe for credential-bearing
// routes. It logs only the URL *path* (never the raw query string), so OAuth
// `code`/`state` values and any other query data can never reach logs.
func NewLogger(out io.Writer) gin.HandlerFunc {
	if out == nil {
		out = os.Stdout
	}
	l := log.New(out, "", log.LstdFlags|log.LUTC)
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		l.Printf("method=%s path=%s status=%d dur=%s",
			c.Request.Method, c.Request.URL.Path, c.Writer.Status(),
			time.Since(start).Round(time.Millisecond))
	}
}

// NewRecovery replaces gin.Recovery with a handler that never dumps the
// request (gin's default recovery prints the full request line including the
// query string, and headers). It logs method and path only.
func NewRecovery(out io.Writer) gin.HandlerFunc {
	if out == nil {
		out = os.Stdout
	}
	l := log.New(out, "", log.LstdFlags|log.LUTC)
	return func(c *gin.Context) {
		defer func() {
			if rec := recover(); rec != nil {
				if rec == http.ErrAbortHandler {
					panic(rec)
				}
				l.Printf("panic method=%s path=%s", c.Request.Method, c.Request.URL.Path)
				c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{"error": "internal error"})
			}
		}()
		c.Next()
	}
}
