package harness

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestMailKeywordCannotBecomeTopLevelSearchOperator(t *testing.T) {
	var query string
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		query = r.URL.Query().Get("q")
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"messages":[]}`))
	}))
	defer upstream.Close()
	g := newGoogleAPI(Config{GoogleClientID: "test", GoogleClientSecret: "test", GoogleRedirectURI: "https://callback.example.test",
		TokenKey: make([]byte, 32), GoogleGmailList: upstream.URL})
	_, _, err := g.SearchTravelMail(context.Background(), TokenSet{AccessToken: "synthetic"}, "OR inbox", time.Unix(1700000000, 0))
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(query, `after:1700000000 (travel OR flight OR hotel`) || !strings.HasSuffix(query, `) "OR inbox"`) {
		t.Fatalf("mail keyword escaped the fixed date/travel boundary: %q", query)
	}
}
