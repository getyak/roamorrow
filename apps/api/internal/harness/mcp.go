package harness

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

// MCP protocol revision implemented by this endpoint (frozen wire contract).
const mcpProtocolVersion = "2025-11-25"

const mcpServerName = "roamorrow-harness"
const mcpServerVersion = "1.0.0"

// JSON-RPC 2.0 error codes used below.
const (
	rpcParseError     = -32700
	rpcInvalidRequest = -32600
	rpcMethodNotFound = -32601
	rpcInvalidParams  = -32602
	rpcInternalError  = -32603
)

const maxMCPBody = int64(256 << 10)

type rpcErrorBody struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type rpcResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcErrorBody   `json:"error,omitempty"`
}

func (s *Server) handleMCPMethodNotAllowed(c *gin.Context) {
	c.Header("Allow", http.MethodPost)
	c.AbortWithStatusJSON(http.StatusMethodNotAllowed, gin.H{"error": "method not allowed"})
}

// handleMCP serves MCP Streamable HTTP in stateless JSON mode: initialize,
// ping, tools/list and tools/call over POST. Notifications get HTTP 202 with
// an empty body; GET (SSE) is not supported and returns 405. The Origin
// header is validated before authentication.
func (s *Server) handleMCP(c *gin.Context) {
	if ct := c.GetHeader("Content-Type"); !strings.HasPrefix(strings.ToLower(strings.TrimSpace(ct)), "application/json") {
		c.AbortWithStatusJSON(http.StatusUnsupportedMediaType, gin.H{"error": "content type must be application/json"})
		return
	}
	if accept := c.GetHeader("Accept"); !strings.Contains(accept, "application/json") {
		c.AbortWithStatusJSON(http.StatusNotAcceptable, gin.H{"error": "accept must include application/json"})
		return
	}
	if v := strings.TrimSpace(c.GetHeader("MCP-Protocol-Version")); v != "" && v != mcpProtocolVersion {
		c.AbortWithStatusJSON(http.StatusBadRequest, gin.H{"error": "unsupported MCP-Protocol-Version"})
		return
	}

	c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxMCPBody)
	raw, err := io.ReadAll(c.Request.Body)
	if err != nil {
		var mbe *http.MaxBytesError
		if errors.As(err, &mbe) {
			c.AbortWithStatusJSON(http.StatusRequestEntityTooLarge, gin.H{"error": "request body too large"})
			return
		}
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: json.RawMessage("null"),
			Error: &rpcErrorBody{Code: rpcParseError, Message: "parse error"}})
		return
	}

	var generic any
	dec := json.NewDecoder(bytes.NewReader(raw))
	dec.UseNumber()
	if err := dec.Decode(&generic); err != nil {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: json.RawMessage("null"),
			Error: &rpcErrorBody{Code: rpcParseError, Message: "parse error"}})
		return
	}
	// A message must be one complete JSON value: trailing `]`/`}`, a second
	// object or any tail is a parse error, so a notification is only ever
	// accepted as a valid complete single JSON-RPC message.
	if err := dec.Decode(new(any)); !errors.Is(err, io.EOF) {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: json.RawMessage("null"),
			Error: &rpcErrorBody{Code: rpcParseError, Message: "parse error"}})
		return
	}
	if _, isBatch := generic.([]any); isBatch {
		// Batching was removed from the protocol; reject it as invalid.
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: json.RawMessage("null"),
			Error: &rpcErrorBody{Code: rpcInvalidRequest, Message: "invalid request: batching unsupported"}})
		return
	}
	obj, isObj := generic.(map[string]any)
	if !isObj {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: json.RawMessage("null"),
			Error: &rpcErrorBody{Code: rpcInvalidRequest, Message: "invalid request"}})
		return
	}

	idRaw, hasID := rawField(raw, "id")
	if hasID {
		if !validRPCID(obj["id"]) {
			s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: json.RawMessage("null"),
				Error: &rpcErrorBody{Code: rpcInvalidRequest, Message: "invalid request: bad id"}})
			return
		}
	} else {
		idRaw = json.RawMessage("null")
	}

	if v, ok := obj["jsonrpc"].(string); !ok || v != "2.0" {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: idRaw,
			Error: &rpcErrorBody{Code: rpcInvalidRequest, Message: "invalid request: jsonrpc must be \"2.0\""}})
		return
	}
	method, ok := obj["method"].(string)
	if !ok || strings.TrimSpace(method) == "" {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: idRaw,
			Error: &rpcErrorBody{Code: rpcInvalidRequest, Message: "invalid request: method required"}})
		return
	}

	params, _ := obj["params"].(map[string]any)

	// Notifications (no id) are accepted with HTTP 202 and no response body.
	if !hasID {
		c.Status(http.StatusAccepted)
		return
	}

	switch method {
	case "initialize":
		s.mcpInitialize(c, idRaw, params)
	case "ping":
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: idRaw, Result: map[string]any{}})
	case "tools/list":
		s.mcpToolsList(c, idRaw, params)
	case "tools/call":
		s.mcpToolsCall(c, idRaw, params)
	default:
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: idRaw,
			Error: &rpcErrorBody{Code: rpcMethodNotFound, Message: "method not found"}})
	}
}

func (s *Server) mcpWrite(c *gin.Context, resp rpcResponse) {
	c.JSON(http.StatusOK, resp)
}

// validRPCID enforces string | number ids per the 2025-11-25 lifecycle.
func validRPCID(v any) bool {
	switch v.(type) {
	case string, json.Number, float64:
		return true
	default:
		return false
	}
}

// rawField re-extracts the raw JSON of a top-level field so responses echo the
// exact id value.
func rawField(raw []byte, key string) (json.RawMessage, bool) {
	var obj map[string]json.RawMessage
	if err := json.Unmarshal(raw, &obj); err != nil {
		return nil, false
	}
	v, ok := obj[key]
	return v, ok
}

func (s *Server) mcpInitialize(c *gin.Context, id json.RawMessage, params map[string]any) {
	version, _ := params["protocolVersion"].(string)
	if strings.TrimSpace(version) == "" {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: protocolVersion required"}})
		return
	}
	info, ok := params["clientInfo"].(map[string]any)
	if !ok {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: clientInfo required"}})
		return
	}
	name, _ := info["name"].(string)
	ver, _ := info["version"].(string)
	if strings.TrimSpace(name) == "" || strings.TrimSpace(ver) == "" {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: clientInfo.name and version required"}})
		return
	}
	if caps, present := params["capabilities"]; present {
		if _, isObj := caps.(map[string]any); !isObj {
			s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
				Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: capabilities must be an object"}})
			return
		}
	}
	// Version negotiation: this server speaks the 2025-11-25 revision only,
	// so it answers with its own revision and the client decides.
	s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id, Result: map[string]any{
		"protocolVersion": mcpProtocolVersion,
		"capabilities": map[string]any{
			"tools": map[string]any{"listChanged": false},
		},
		"serverInfo": map[string]any{"name": mcpServerName, "version": mcpServerVersion},
	}})
}

func (s *Server) mcpToolsList(c *gin.Context, id json.RawMessage, params map[string]any) {
	if cursor, ok := params["cursor"]; ok && cursor != nil {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: no pagination, cursor unsupported"}})
		return
	}
	names := []string{"get_traveler_profile", "list_calendar_events", "search_travel_mail"}
	tools := make([]map[string]any, 0, len(names))
	for _, n := range names {
		t := toolRegistry[n]
		tools = append(tools, map[string]any{
			"name":        t.name,
			"description": t.description,
			"inputSchema": t.inputSchema,
			"annotations": map[string]any{
				"readOnlyHint":    true,
				"destructiveHint": false,
				"idempotentHint":  true,
				"openWorldHint":   n != "get_traveler_profile",
			},
		})
	}
	s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id, Result: map[string]any{"tools": tools}})
}

func (s *Server) mcpToolsCall(c *gin.Context, id json.RawMessage, params map[string]any) {
	ident, _ := IdentityFrom(c)
	if s.store == nil {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInternalError, Message: "database not configured"}})
		return
	}
	// Strict params: only name, arguments and _meta.
	for k := range params {
		if k != "name" && k != "arguments" && k != "_meta" {
			s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
				Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: unexpected field"}})
			return
		}
	}
	name, ok := params["name"].(string)
	if !ok || !toolNamePattern.MatchString(name) {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: name required"}})
		return
	}
	if _, ok := toolRegistry[name]; !ok {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: unknown tool"}})
		return
	}
	var argsJSON json.RawMessage
	if rawArgs, ok := params["arguments"]; ok && rawArgs != nil {
		b, err := json.Marshal(rawArgs)
		if err != nil {
			s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
				Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: arguments must be an object"}})
			return
		}
		argsJSON = b
	}

	release, err := s.limiter.Acquire(ident.ID)
	if err != nil {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id, Result: map[string]any{
			"content": []map[string]any{{"type": "text", "text": `{"status":"error","error":"rate limit exceeded"}`}},
			"isError": true,
		}})
		return
	}
	defer release()

	result, err := s.ExecuteTool(c.Request.Context(), ident, name, argsJSON, false)
	if err != nil {
		s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id,
			Error: &rpcErrorBody{Code: rpcInvalidParams, Message: "invalid params: invalid arguments"}})
		return
	}
	text := boundToolContent(result)
	s.mcpWrite(c, rpcResponse{JSONRPC: "2.0", ID: id, Result: map[string]any{
		"content": []map[string]any{{"type": "text", "text": text}},
		"isError": result.Status != "ok",
	}})
}
