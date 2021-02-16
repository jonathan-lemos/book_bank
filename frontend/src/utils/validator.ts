import {Failure, Result, Success} from "./functional/result";

export type Schema = string | number | null | undefined | boolean | {[key: string]: Schema} | Schema[];

export function schema_stringify(s: Schema, pretty?: boolean): string {
  if (Array.isArray(s)) {
    if (s.length == 1) {
      return `${JSON.stringify(s[0])}[]`
    }
    return s.sort().map(x => schema_stringify(x, pretty)).join(` or `);
  }
  if (typeof s === "object") {
    const k = Object.keys(s).filter(k => s.hasOwnProperty(k)).sort();
    if (pretty) {
return `{
${k.map(x => `  ${x}: ${schema_stringify(x)}`).join(",\n  ")}
}`;
    }
    else {
      return `{${k.map(x => `${x}: ${schema_stringify(x)}`).join(", ")}}`
    }
  }
  if (["boolean", "string", "undefined", "null", "number"].some(x => x === s)) {
    return s as string;
  }
  return JSON.stringify(s)
}

export default function validate<T>(a: any, schema: Schema): Result<T, string> {
  if (a === schema) {
    return new Success(a);
  }

  if (["boolean", "number", "string", "null", "undefined", "object"].some(t => schema === t && typeof a === t)) {
    return new Success(a);
  }

  if (Array.isArray(schema)) {
    // if [string]
    if (schema.length === 1) {
      // check if all of a are string
      if (!Array.isArray(a)) {
        return new Failure(`Expected an array, got ${JSON.stringify(a)}.`)
      }

      const errorMessages = a.map((e, i) => {
        const res = validate<T>(e, schema[0]);
        if (res.isError()) {
          return `Error with array element ${JSON.stringify(a[i])}:\n${res.value}`;
        }
        else {
          return null;
        }
      }).filter(x => x != null);

      if (errorMessages.length > 0) {
        return new Failure(errorMessages.join("\n"));
      }

      return new Success((a as unknown) as any);
    }

    // if [string, number], check that this specific a is a string or a number
    if (schema.some(s => validate(a, s))) {
      return new Success(a);
    }
    else {
      return new Failure(`Expected at least one of ${schema_stringify(schema)}, got ${JSON.stringify(a)}`);
    }
  }

  if (typeof schema === "object") {
    if (typeof a !== "object") {
      return new Failure(`Expected ${schema_stringify(schema)}, got ${JSON.stringify(a)}`);
    }

    for (const key in schema) {
      if (!a.hasOwnProperty(key)) {
        return new Failure(`Error with ${JSON.stringify(a)}. Expected ${key}: ${schema_stringify(schema[key])}, but no ${key} was present in the object.`);
      }
      const res = validate(a[key], schema[key]);
      if (res.isError()) {
        return new Failure(`Error with ${JSON.stringify(a)}:\n${res.value}`);
      }
    }
    return new Success(a);
  }
  else {
    return new Failure(`Error with ${JSON.stringify(a)}. Expected ${schema_stringify(schema)}.`)
  }
}

