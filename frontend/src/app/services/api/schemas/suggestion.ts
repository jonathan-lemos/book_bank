import {Schema} from "../../../../utils/validator";

export default interface Suggestion {
  id: string,
  text: string,
  tag: string
}

export const SuggestionSchema: Schema = {
  id: "string",
  text: "string",
  tag: "string"
}
