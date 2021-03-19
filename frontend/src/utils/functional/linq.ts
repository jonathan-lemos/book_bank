type NestedList<T> = (T | NestedList<T>)[]

export function flatten<T>(a: NestedList<T>): T[] {
  const ret = [];

  for (const elem of a) {
    if (Array.isArray(elem)) {
      ret.push(...flatten(elem));
    } else {
      ret.push(elem);
    }
  }

  return ret;
}

export function enumerate<T>(a: T[]): [number, T][] {
  return a.map((e, i) => [i, e]);
}

export function range(n: number, end?: number, step?: number): number[] {
  if (end === undefined && step === undefined) {
    const ret = [];
    for (let i = 0; i < n; ++i) {
      ret.push(i);
    }
    return ret;
  }

  if (step === undefined) {
    const ret = [];
    if (n <= end!) {
      for (let i = n; i < end!; ++i) {
        ret.push(i);
      }
    } else {
      for (let i = n; i > end!; --i) {
        ret.push(i);
      }
    }
    return ret;
  }

  const ret = [];
  if (n <= end!) {
    if (step < 0) {
      step = -step;
    }

    for (let i = n; i < end!; i += step) {
      ret.push(i);
    }
  } else {
    if (step > 0) {
      step = -step;
    }

    for (let i = n; i > end!; i += step) {
      ret.push(i);
    }
  }

  return ret;
}

export function zip<T1, T2>(first: T1[], second: T2[]): [T1, T2][] {
  if (first.length > second.length) {
    return second.map((e, i) => [first[i], e]);
  }
  else {
    return first.map((e, i) => [e, second[i]]);
  }
}
