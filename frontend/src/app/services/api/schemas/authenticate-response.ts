import Literal from "src/utils/validation/literal";
import Record from "src/utils/validation/record";
import Schema from "src/utils/validation/schema";
import Type from "src/utils/validation/type";
import Union from "src/utils/validation/union";

export type AuthenticateResponse = {
  status: number,
  response: string,
  token: string | null
}

export const AuthenticateResponseSchema: Schema = new Record({
  status: new Type("number"),
  response: new Type("string"),
  token: new Union(new Type("string"), new Literal(null))
})

export default AuthenticateResponse;
