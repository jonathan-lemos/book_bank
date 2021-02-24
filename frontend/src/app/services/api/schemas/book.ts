import Record from "src/utils/validation/record";
import Schema from "src/utils/validation/schema";
import StringDictionary from "src/utils/validation/string_dictionary";
import Type from "src/utils/validation/type";

export default interface Book {
  id: string,
  title: string,
  size: number,
  metadata: { [key: string]: string },
}

export const BookSchema: Schema = new Record({
  id: new Type("string"),
  title: new Type("string"),
  size: new Type("number"),
  metadata: new StringDictionary(new Type("string"))
});
