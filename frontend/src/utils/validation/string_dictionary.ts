import { Failure, Result, Success } from "../functional/result";
import Schema from "./schema";

export default class StringDictionary extends Schema {
    private readonly valueSchema : Schema;

    public constructor(values: Schema) {
        super();
        this.valueSchema = values;
    }

    public validate(a: any): Result<void, string> {
        if (typeof a !== "object") {
            return new Failure(`Expected ${this.toString()}, got ${JSON.stringify(a)}`);
        }
        for (const key of Object.keys(a)) {
            if (!a.hasOwnProperty(key)) {
                continue;
            }

            const res = this.valueSchema.validate(a[key]);
            if (res.isError()) {
                return res;
            }
        }

        return new Success(null);
    }

    public toString() {
        return `{[key: string]: ${this.valueSchema.toString()}}`;
    }
}