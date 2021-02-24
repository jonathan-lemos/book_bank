import List from "src/utils/validation/list";
import Record from "src/utils/validation/record";
import Schema from "src/utils/validation/schema";
import Type from "src/utils/validation/type";
import Book, {BookSchema} from "./book";

export default interface SearchResponse {
  status: number,
  response: string,
  results: Book[]
}

export const SearchResponseSchema: Schema = new Record({
  status: new Type("number"),
  response: new Type("string"),
  results: new List(BookSchema)
});
