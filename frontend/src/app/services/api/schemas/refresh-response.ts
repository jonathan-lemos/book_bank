export default interface RefreshResponse {
  status: number;
  response: string;
  token: string | null;
}

export const RefreshResponseSchema = {
  status: "number",
  response: "string",
  token: ["string", null]
}
