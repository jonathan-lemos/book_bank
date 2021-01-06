import {Schema} from "../../../../utils/validator";

export type AuthenticateResponse = {
  status: number,
  response: string,
  token: string | null
}

export const AuthenticateResponseSchema: Schema = {
  status: "number",
  response: "string",
  token: ["string", null]
}

export default AuthenticateResponse;
