import Schema from "../../../../utils/validation/schema";
import Record from "../../../../utils/validation/record";
import Type from "../../../../utils/validation/type";

export default interface CreateAccountResponse {
  status: number,
  response: string,
  username: string
}

export const CreateAccountResponseSchema: Schema = new Record({
  status: new Type("number"),
  response: new Type("string"),
  username: new Type("string")
});
