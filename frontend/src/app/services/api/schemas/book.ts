import validate, {Schema} from "../../../../utils/validator";

export default interface Book {
  id: string,
  title: string,
  size: number,
  metadata: {key: string, value: string}[],
}

export const BookSchema: Schema = {
  id: "string",
  title: "string",
  size: "number",
  metadata: [{key: "string", value: "string"}]
}

