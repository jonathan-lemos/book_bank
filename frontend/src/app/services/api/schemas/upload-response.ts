export default interface UploadResponse {
  status: number,
  response: string,
  id: string
}

export const UploadResponseSchema = {
  status: "number",
  response: "string",
  id: "string"
}
