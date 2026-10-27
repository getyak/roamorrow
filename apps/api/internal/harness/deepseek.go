package harness

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"
)

// errModel is a sanitized DeepSeek failure (no response bodies, keys or prompt
// text in messages).
var errModel = errors.New("harness: model request failed")

// ToolCallReq is one OpenAI-format tool invocation requested by the model.
type ToolCallReq struct {
	ID       string `json:"id"`
	Type     string `json:"type"`
	Function struct {
		Name      string `json:"name"`
		Arguments string `json:"arguments"`
	} `json:"function"`
}

// ChatMsg is one OpenAI-format chat message. Content is never logged.
type ChatMsg struct {
	Role       string        `json:"role"`
	Content    string        `json:"content,omitempty"`
	ToolCalls  []ToolCallReq `json:"tool_calls,omitempty"`
	ToolCallID string        `json:"tool_call_id,omitempty"`
}

// ChatRequest is one round of the bounded tool loop.
type ChatRequest struct {
	Messages []ChatMsg
	Tools    []map[string]any
}

// ChatResponse is the model's message for one round.
type ChatResponse struct {
	Content   string
	ToolCalls []ToolCallReq
}

// DeepSeekClient abstracts the DeepSeek OpenAI-compatible endpoint.
type DeepSeekClient interface {
	Chat(ctx context.Context, req ChatRequest) (ChatResponse, error)
}

// deepseekClient calls POST {base}/chat/completions with the server-owned
// model and thinking disabled. Redirects are disabled; request/response text
// never reaches logs.
type deepseekClient struct {
	apiKey string
	url    string
	client *http.Client
	model  string
}

func newDeepSeekClient(cfg Config) *deepseekClient {
	if !cfg.deepseekConfigured() {
		return nil
	}
	return &deepseekClient{
		apiKey: cfg.DeepSeekAPIKey,
		url:    strings.TrimRight(cfg.DeepSeekBaseURL, "/") + "/chat/completions",
		client: noRedirectClient(90 * time.Second),
		model:  ChatModel,
	}
}

func (d *deepseekClient) Chat(ctx context.Context, req ChatRequest) (ChatResponse, error) {
	if d == nil || d.apiKey == "" {
		return ChatResponse{}, errors.New("harness: deepseek not configured")
	}
	payload := map[string]any{
		"model":      d.model,
		"stream":     false,
		"max_tokens": 1024,
		// Server-owned: thinking stays disabled for the bounded harness loop.
		"thinking":    map[string]string{"type": "disabled"},
		"tool_choice": "auto",
		"messages":    req.Messages,
	}
	if len(req.Tools) > 0 {
		payload["tools"] = req.Tools
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return ChatResponse{}, errModel
	}
	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost, d.url, bytes.NewReader(body))
	if err != nil {
		return ChatResponse{}, errModel
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.Header.Set("Authorization", "Bearer "+d.apiKey)
	httpReq.Header.Set("Accept", "application/json")

	resp, err := d.client.Do(httpReq)
	if err != nil {
		return ChatResponse{}, errModel
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		// Drain bounded; status only, body discarded.
		io.Copy(io.Discard, io.LimitReader(resp.Body, maxAuthBody))
		return ChatResponse{}, errModel
	}
	raw, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return ChatResponse{}, errModel
	}
	var parsed struct {
		Choices []struct {
			Message struct {
				Content   string        `json:"content"`
				ToolCalls []ToolCallReq `json:"tool_calls"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return ChatResponse{}, errModel
	}
	if len(parsed.Choices) == 0 {
		return ChatResponse{}, errModel
	}
	m := parsed.Choices[0].Message
	return ChatResponse{Content: m.Content, ToolCalls: m.ToolCalls}, nil
}

// openAITools renders the registry as OpenAI function tools for the model.
// The model can only ever see the three bounded read tools.
func openAITools(names []string) []map[string]any {
	out := make([]map[string]any, 0, len(names))
	for _, n := range names {
		t := toolRegistry[n]
		if t == nil {
			continue
		}
		out = append(out, map[string]any{
			"type": "function",
			"function": map[string]any{
				"name":        t.name,
				"description": t.description,
				"parameters":  t.inputSchema,
			},
		})
	}
	return out
}
