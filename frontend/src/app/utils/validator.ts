export type Schema = string | null | undefined | {[key: string]: Schema} | Schema[];

export default function validate<T>(a: any, schema: Schema): a is T {
  if (a === schema) {
    return true;
  }

  if (["boolean", "number", "string", "null", "undefined"].some(t => schema === t && typeof a === t)) {
    return true;
  }

  if (Array.isArray(schema)) {
    // if [string]
    if (schema.length === 1) {
      // check if all of a are string
      return Array.isArray(a) ? a.every(e => validate(e, schema[0])) : false;
    }

    // if [string, number], check that this specific a is a string or a number
    return schema.some(s => validate(a, s));
  }

  if (typeof  === "object") {
    if (typeof a !== "object") {
      return false;
    }
    for (const key in schema) {
      if (!a.hasOwnProperty(key)) {
        return
      }
    }
  }

  return false;
}

