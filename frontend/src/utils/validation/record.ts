import { Failure, Result, Success } from "../functional/result";
import Schema from "./schema";

export default class Record extends Schema {
    private readonly record: { [key: string]: Schema };

    public constructor(record: { [key: string]: Schema }) {
        super();
        this.record = record;
    }

    public validate(a: any): Result<void, string> {
        if (typeof a !== "object") {
            return new Failure(`Expected ${this.toString()}, got ${JSON.stringify(a)}`);
        }

        for (const key in this.record) {
            if (!this.record.hasOwnProperty(key)) {
                continue;
            }

            if (!a.hasOwnProperty(key)) {
                return new Failure(`Expected '${key}' in ${this.toString()}, but was not present in ${JSON.stringify(a)}`);
            }

            const res = this.record[key].validate(a[key]);
            if (res.isError()) {
                return res;
            }
        }

        return new Success(null);
    }

    public toString() {
        const newObject = Object.keys(this.record)
            .map(key => [key, this.record[key].toString()])
            .reduce((a, [key, value]) => Object.assign(a, { [key]: value }), {});

        return JSON.stringify(newObject);
    }
}