import validate, {Schema} from "../../../../utils/validator";

export default interface Book {
  id: string,
  title: string,
  isbn: string | null,
  authors: string[],
  tags: string[],
}

export const BookSchema: Schema = {
  id: "string",
  title: "string",
  isbn: ["string", null],
  authors: ["string"],
  tags: ["string"]
}

