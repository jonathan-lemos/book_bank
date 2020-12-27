export default interface UnauthorizedResponse {
  status: 401,
  response: "unauthorized",
  reason: "missing token" | "expired token" | "invalid token"
}

export const UnauthorizedResponseSchema = {
  status: 401,
  response: "unauthorized",
  reason: ["missing token", "expired token", "invalid token"]
}
