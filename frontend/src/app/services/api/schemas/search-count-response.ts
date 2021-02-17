import Record from "src/utils/validation/record";
import Schema from "src/utils/validation/schema";
import Type from "src/utils/validation/type";

export default interface SearchCountResponse {
  status: number,
  response: string,
  count: number
}

export const SearchCountResponseSchema: Schema = new Record({
  status: new Type("number"),
  response: new Type("string"),
  count: new Type("number")
});
