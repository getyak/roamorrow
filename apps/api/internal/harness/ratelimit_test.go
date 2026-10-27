package harness

import (
	"sync"
	"testing"
	"time"
)

func TestLimiterPerUserBudget(t *testing.T) {
	l := NewLimiter(3, 4, 8)
	now := time.Now()
	l.now = func() time.Time { return now }

	for i := 0; i < 3; i++ {
		rel, err := l.Acquire("user-a")
		if err != nil {
			t.Fatalf("acquire %d: %v", i, err)
		}
		rel()
	}
	if _, err := l.Acquire("user-a"); err != ErrRateLimited {
		t.Fatalf("4th acquire must be rate limited, got %v", err)
	}
	if _, err := l.Acquire("user-b"); err != nil {
		t.Fatalf("other user must have its own budget, got %v", err)
	}

	// Budget refills over time.
	l.now = func() time.Time { return now.Add(time.Minute) }
	rel, err := l.Acquire("user-a")
	if err != nil {
		t.Fatalf("budget must refill: %v", err)
	}
	rel()
}

func TestLimiterConcurrency(t *testing.T) {
	l := NewLimiter(100, 2, 4)
	rel1, err := l.Acquire("user-a")
	if err != nil {
		t.Fatal(err)
	}
	rel2, err := l.Acquire("user-a")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := l.Acquire("user-a"); err != ErrConcurrencyLimited {
		t.Fatalf("3rd concurrent must fail, got %v", err)
	}
	// Failed acquire must not burn rate budget.
	rel1()
	rel2()
	for i := 0; i < 3; i++ {
		rel, err := l.Acquire("user-a")
		if err != nil {
			t.Fatalf("acquire after release %d: %v", i, err)
		}
		rel()
	}
}

func TestLimiterGlobalConcurrency(t *testing.T) {
	l := NewLimiter(100, 4, 2)
	var releases []func()
	for _, u := range []string{"a", "b"} {
		rel, err := l.Acquire(u)
		if err != nil {
			t.Fatal(err)
		}
		releases = append(releases, rel)
	}
	if _, err := l.Acquire("c"); err != ErrConcurrencyLimited {
		t.Fatalf("global cap must bind, got %v", err)
	}
	releases[0]()
	releases[1]()
	rel, err := l.Acquire("c")
	if err != nil {
		t.Fatalf("after release must succeed: %v", err)
	}
	rel()
}

func TestLimiterReleaseIdempotent(t *testing.T) {
	l := NewLimiter(100, 1, 2)
	rel, err := l.Acquire("user-a")
	if err != nil {
		t.Fatal(err)
	}
	rel()
	rel() // double release must not corrupt the semaphore
	rel2, err := l.Acquire("user-a")
	if err != nil {
		t.Fatal(err)
	}
	rel2()
}

func TestLimiterConcurrentAcquire(t *testing.T) {
	l := NewLimiter(1000, 4, 8)
	var wg sync.WaitGroup
	errs := make(chan error, 50)
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			rel, err := l.Acquire("user-a")
			if err != nil {
				errs <- err
				return
			}
			time.Sleep(time.Millisecond)
			rel()
		}()
	}
	wg.Wait()
	close(errs)
	for err := range errs {
		if err != ErrConcurrencyLimited {
			t.Fatalf("unexpected error under concurrency: %v", err)
		}
	}
}
