import {Failure, Result, Success} from "../functional/result";
import Schema from "./schema";

export default class List extends Schema {
  private readonly elem: Schema;

  public constructor(elem: Schema) {
    super();
    this.elem = elem;
  }

  public validate(a: any): Result<void, string> {
    if (!Array.isArray(a)) {
      return new Failure(`Expected ${this.toString()}, but ${JSON.stringify(a)} was not an array.`);
    }

    for (const e of a) {
      const res = this.elem.validate(e);
      if (res.isError()) {
        return res;
      }
    }

    return new Success(null);
  }

  public toString() {
    return `${this.elem.toString()}[]`;
  }
}
