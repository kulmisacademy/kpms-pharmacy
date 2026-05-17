/** JSON body for Edge + Flutter; `success` mirrors HTTP 2xx. */
export function jsonResponse(
  status: number,
  body: Record<string, unknown>,
): Response {
  const success = status >= 200 && status < 300;
  return new Response(JSON.stringify({ success, ...body }), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
