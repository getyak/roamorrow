package harness

import (
	"bytes"
	"strings"
	"testing"
)

func TestCipherRoundTrip(t *testing.T) {
	c, err := NewCipher(testKey)
	if err != nil {
		t.Fatal(err)
	}
	ct, err := c.SealToken("user-a", purposeRefresh, []byte("refresh-token-secret"))
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(ct, []byte("refresh-token-secret")) {
		t.Fatal("ciphertext contains plaintext")
	}
	pt, err := c.OpenToken("user-a", purposeRefresh, ct)
	if err != nil {
		t.Fatal(err)
	}
	if string(pt) != "refresh-token-secret" {
		t.Fatalf("round trip mismatch: %q", pt)
	}
}

func TestCipherFreshNonce(t *testing.T) {
	c, err := NewCipher(testKey)
	if err != nil {
		t.Fatal(err)
	}
	a, _ := c.SealToken("user-a", purposeAccess, []byte("same"))
	b, _ := c.SealToken("user-a", purposeAccess, []byte("same"))
	if bytes.Equal(a, b) {
		t.Fatal("identical ciphertext for identical plaintext: nonce reuse")
	}
}

func TestCipherWrongKeyAndTamper(t *testing.T) {
	c, err := NewCipher(testKey)
	if err != nil {
		t.Fatal(err)
	}
	ct, err := c.SealToken("user-a", purposeAccess, []byte("secret"))
	if err != nil {
		t.Fatal(err)
	}
	other, err := NewCipher([]byte("ffffffffffffffffffffffffffffffff"))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := other.OpenToken("user-a", purposeAccess, ct); err == nil {
		t.Fatal("decryption with wrong key must fail")
	}
	tampered := append([]byte{}, ct...)
	tampered[len(tampered)-1] ^= 0xff
	if _, err := c.OpenToken("user-a", purposeAccess, tampered); err == nil {
		t.Fatal("tampered ciphertext must fail")
	}
	if _, err := c.OpenToken("user-a", purposeAccess, nil); err == nil {
		t.Fatal("empty ciphertext must fail")
	}
}

// TestCipherAADBindsOwnerAndPurpose proves ciphertext cannot be swapped
// between owners or between the access/refresh/PKCE slots (P2-9).
func TestCipherAADBindsOwnerAndPurpose(t *testing.T) {
	c, err := NewCipher(testKey)
	if err != nil {
		t.Fatal(err)
	}
	ct, err := c.SealToken("user-a", purposeAccess, []byte("secret"))
	if err != nil {
		t.Fatal(err)
	}
	// Cross-owner swap must fail.
	if _, err := c.OpenToken("user-b", purposeAccess, ct); err == nil {
		t.Fatal("cross-owner ciphertext must fail to decrypt")
	}
	// Cross-purpose swap must fail (access used as refresh, as PKCE verifier).
	if _, err := c.OpenToken("user-a", purposeRefresh, ct); err == nil {
		t.Fatal("access ciphertext opened as refresh must fail")
	}
	if _, err := c.OpenToken("user-a", purposePKCEVerifier, ct); err == nil {
		t.Fatal("access ciphertext opened as pkce verifier must fail")
	}
	// Raw AAD must not match the bound helper format.
	if _, err := c.Open([]byte("user-a|google-access"), ct); err == nil {
		t.Fatal("raw aad must not decrypt bound ciphertext")
	}
	// AAD strings must differ per owner/purpose.
	if bytes.Equal(TokenAAD("user-a", purposeAccess), TokenAAD("user-b", purposeAccess)) {
		t.Fatal("aad must bind owner")
	}
	if bytes.Equal(TokenAAD("user-a", purposeAccess), TokenAAD("user-a", purposeRefresh)) {
		t.Fatal("aad must bind purpose")
	}
}

func TestNewCipherRejectsBadKey(t *testing.T) {
	if _, err := NewCipher([]byte("short")); err == nil {
		t.Fatal("short key must be rejected")
	} else if !strings.Contains(err.Error(), "32") {
		t.Fatalf("error should mention key size, got %v", err)
	}
}
