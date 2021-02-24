import {Failure, Result} from "../functional/result";
import Schema from "./schema";

export default class Union extends Schema {
  private readonly schemas: Schema[];

  public constructor(...schemas: Schema[]) {
    super();
    this.schemas = schemas;
  }

  public validate(a: any): Result<void, string> {
    const errors = [];

    for (const schema of this.schemas) {
      const res = schema.validate(a);

      if (res.isError()) {
        errors.push(res);
      } else {
        return res;
      }
    }

    return new Failure(`Did not match ${this.toString()}. ${errors.map(x => x.value).join(", ")}`);
  }

  public toString() {
    return this.schemas.map(x => x.toString()).join(" | ");
  }
}
