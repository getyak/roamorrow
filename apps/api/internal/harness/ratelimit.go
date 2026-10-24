package harness

import (
	"errors"
	"sync"
	"time"
)

// ErrRateLimited is returned when the per-user request budget is exhausted.
var ErrRateLimited = errors.New("harness: rate limit exceeded")

// ErrConcurrencyLimited is returned when the per-user or global concurrency
// budget for paid upstream calls is exhausted.
var ErrConcurrencyLimited = errors.New("harness: concurrency limit reached")

// Limiter rate-limits paid operations per verified user and bounds how many
// paid upstream calls one user (and the whole process) may run concurrently.
// Identity comes from verified auth only.
type Limiter struct {
	mu       sync.Mutex
	perMin   float64
	maxUser  int
	maxTotal int
	buckets  map[string]*tokenBucket
	userSem  map[string]chan struct{}
	totalSem chan struct{}
	now      func() time.Time
}

type tokenBucket struct {
	tokens float64
	last   time.Time
}

// NewLimiter builds a limiter allowing perMin requests/minute (with a burst of
// perMin), at most maxUser concurrent paid calls per user and maxTotal overall.
func NewLimiter(perMin, maxUser, maxTotal int) *Limiter {
	if perMin <= 0 {
		perMin = 6
	}
	if maxUser <= 0 {
		maxUser = 2
	}
	if maxTotal <= 0 {
		maxTotal = 8
	}
	return &Limiter{
		perMin:   float64(perMin),
		maxUser:  maxUser,
		maxTotal: maxTotal,
		buckets:  map[string]*tokenBucket{},
		userSem:  map[string]chan struct{}{},
		totalSem: make(chan struct{}, maxTotal),
		now:      time.Now,
	}
}

// Acquire reserves one paid request for userID. The returned release func must
// be called exactly once after the upstream work completes (or on error paths
// after a successful acquire).
func (l *Limiter) Acquire(userID string) (release func(), err error) {
	now := l.now()
	l.mu.Lock()
	b := l.buckets[userID]
	if b == nil {
		b = &tokenBucket{tokens: l.perMin, last: now}
		l.buckets[userID] = b
	}
	elapsed := now.Sub(b.last).Minutes()
	if elapsed > 0 {
		b.tokens += elapsed * l.perMin
		if b.tokens > l.perMin {
			b.tokens = l.perMin
		}
		b.last = now
	}
	if b.tokens < 1 {
		l.mu.Unlock()
		return nil, ErrRateLimited
	}
	b.tokens--

	us := l.userSem[userID]
	if us == nil {
		us = make(chan struct{}, l.maxUser)
		l.userSem[userID] = us
	}
	l.mu.Unlock()

	// Non-blocking concurrency acquisition: a backed-up user gets a fast,
	// honest failure instead of queued paid work.
	select {
	case us <- struct{}{}:
	default:
		l.refund(userID)
		return nil, ErrConcurrencyLimited
	}
	select {
	case l.totalSem <- struct{}{}:
	default:
		<-us
		l.refund(userID)
		return nil, ErrConcurrencyLimited
	}
	var once sync.Once
	return func() {
		once.Do(func() {
			<-l.totalSem
			<-us
		})
	}, nil
}

// refund returns one rate token after a failed concurrency acquire so the
// request budget is not silently consumed by rejected work.
func (l *Limiter) refund(userID string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if b := l.buckets[userID]; b != nil && b.tokens < l.perMin {
		b.tokens++
	}
}
