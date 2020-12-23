import validator, {Schema} from "../../../utils/validator";

export type AuthenticateResponse = {
  status: number,
  token: string
}

const AuthenticateResponseSchema: Schema = {
  status: "number",
  response: "string",
  token: ["string", null]
}

export default AuthenticateResponse;

export const isAuthenticateResponse = (a: any): a is AuthenticateResponse {
}
