package harness

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"errors"
	"fmt"
	"io"
)

// ErrDecrypt is returned when ciphertext cannot be opened (wrong key, tampered
// data, wrong owner/purpose binding, or malformed framing). It never
// distinguishes causes to callers.
var ErrDecrypt = errors.New("harness: token decryption failed")

// Cipher wraps AES-256-GCM for provider token encryption at rest. Ciphertext
// framing is nonce || sealed; keys are never persisted or logged. Every
// Seal/Open carries AAD binding the ciphertext to owner + provider + purpose
// so a value swapped between users or between the access/refresh/PKCE slots
// fails to decrypt.
type Cipher struct {
	aead cipher.AEAD
}

// Token purposes for AAD binding.
const (
	purposeAccess       = "google-access"
	purposeRefresh      = "google-refresh"
	purposePKCEVerifier = "google-pkce-verifier"
)

// TokenAAD builds the associated data binding a ciphertext to its owner
// (verified user id), provider and purpose. Format:
// "roamorrow-harness/v1|<userID>|<purpose>".
func TokenAAD(userID, purpose string) []byte {
	return []byte("roamorrow-harness/v1|" + userID + "|" + purpose)
}

// NewCipher builds a Cipher from a 32-byte AES key.
func NewCipher(key []byte) (*Cipher, error) {
	if len(key) != 32 {
		return nil, fmt.Errorf("harness: token key must be 32 bytes, got %d", len(key))
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	return &Cipher{aead: aead}, nil
}

// Seal encrypts plaintext with a fresh random nonce under the given AAD.
func (c *Cipher) Seal(aad, plaintext []byte) ([]byte, error) {
	if c == nil || c.aead == nil {
		return nil, errors.New("harness: cipher not configured")
	}
	nonce := make([]byte, c.aead.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	return c.aead.Seal(nonce, nonce, plaintext, aad), nil
}

// Open decrypts nonce-prefixed ciphertext produced by Seal for the same AAD.
func (c *Cipher) Open(aad, ciphertext []byte) ([]byte, error) {
	if c == nil || c.aead == nil {
		return nil, ErrDecrypt
	}
	ns := c.aead.NonceSize()
	if len(ciphertext) < ns {
		return nil, ErrDecrypt
	}
	plain, err := c.aead.Open(nil, ciphertext[:ns], ciphertext[ns:], aad)
	if err != nil {
		return nil, ErrDecrypt
	}
	return plain, nil
}

// SealToken and OpenToken bind provider tokens to owner + purpose.
func (c *Cipher) SealToken(userID, purpose string, plaintext []byte) ([]byte, error) {
	return c.Seal(TokenAAD(userID, purpose), plaintext)
}

// OpenToken opens provider ciphertext bound to owner + purpose.
func (c *Cipher) OpenToken(userID, purpose string, ciphertext []byte) ([]byte, error) {
	return c.Open(TokenAAD(userID, purpose), ciphertext)
}
