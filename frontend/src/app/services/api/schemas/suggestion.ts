import {Schema} from "../../../../utils/validator";

export default interface Suggestion {
  id: string,
  text: string,
  type: "author" | "isbn" | "tag" | "title"
}

export const SuggestionSchema: Schema = {
  id: "string",
  text: "string",
  type: ["author", "isbn", "tag", "title"]
}
