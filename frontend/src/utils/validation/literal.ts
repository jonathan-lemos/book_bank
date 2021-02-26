import {Failure, Result, Success} from "../functional/result";
import Schema from "./schema";

type LiteralType = boolean | string | number | null;

export default class Literal extends Schema {
  private readonly value: LiteralType;

  public constructor(value: LiteralType) {
    super();
    this.value = value;
  }

  public validate(a: any): Result<void, string> {
    if (a === this.value) {
      return new Success(undefined);
    } else {
      return new Failure(`${JSON.stringify(a)} !== ${this.toString()}.`);
    }
  }

  public toString() {
    return JSON.stringify(this.value, null, 2);
  }
}
