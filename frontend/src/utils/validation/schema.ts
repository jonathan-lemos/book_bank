import { Result } from "../functional/result";

export default abstract class Schema {
  abstract validate(a: any): Result<void, string>;
  abstract toString(): string;
}