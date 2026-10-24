/** Shared JWT parsing/verification only; resource authorization stays in each handler. */
export interface AuthUserClient {
  auth: {
    getUser(jwt?: string): PromiseLike<{
      data: { user: { id: string } | null };
      error: unknown;
    }>;
  };
}

export function bearerToken(request: Request): string {
  return (request.headers.get("Authorization") ?? "").replace(/^Bearer /i, "");
}

export async function verifiedUserId(client: AuthUserClient, jwt?: string): Promise<string | null> {
  const { data, error } = await client.auth.getUser(jwt);
  return error || !data.user ? null : data.user.id;
}

export function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
  });
}

export async function authenticateBearerRequest(
  request: Request,
  createUserClient: (jwt: string) => AuthUserClient,
): Promise<{ userId: string } | Response> {
  const jwt = bearerToken(request);
  if (!jwt) return json({ error: "missing bearer token" }, 401);
  const userId = await verifiedUserId(createUserClient(jwt));
  return userId === null ? json({ error: "unauthorized" }, 401) : { userId };
}
