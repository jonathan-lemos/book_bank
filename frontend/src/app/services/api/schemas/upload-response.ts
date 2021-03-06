import Record from "src/utils/validation/record";
import Schema from "src/utils/validation/schema";
import Type from "src/utils/validation/type";

export default interface UploadResponse {
  status: number,
  response: string,
  id: string
}

export const UploadResponseSchema: Schema = new Record({
  status: new Type("number"),
  response: new Type("string"),
  id: new Type("string")
});
