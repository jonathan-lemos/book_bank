import {Failure, Result, Success} from "../functional/result";
import Schema from "./schema";

export type ValidType = "string" | "boolean" | "number" | "any";

export default class Type extends Schema {
  private readonly type: ValidType;

  public constructor(type: ValidType) {
    super()
    this.type = type;
  }

  public validate(a: any): Result<void, string> {
    if (this.type === "any" || typeof a === this.type) {
      return new Success(null);
    } else {
      return new Failure(`${JSON.stringify(a)} is not a ${this.type}`);
    }
  }

  public toString() {
    return this.type;
  }
}
