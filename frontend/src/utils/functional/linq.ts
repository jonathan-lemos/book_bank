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

declare global {
  interface Array<T> {
    enumerate(): [Number, T][];
    first: T;
    last: T;
    reversed(): T[];
    sorted(compare?: (a: T, b: T) => number): T[];
    zip<TOther>(other: TOther[]): [T, TOther][];
  }
}

Array.prototype.enumerate = function() {
  return this.map((e, i) => [i, e]);
}

Object.defineProperty(Array.prototype, "first", {
  get: function () {
    if (this.length === 0) {
      throw new Error(".first on empty array.");
    }
    else {
      return this[0];
    }
  },
  set: function (value) {
    if (this.length === 0) {
      this.push(value);
    }
    else {
      this[0] = value;
    }
  }
});

Object.defineProperty(Array.prototype, "last", {
  get: function () {
    if (this.length === 0) {
      throw new Error(".first on empty array.");
    }
    else {
      return this[this.length - 1];
    }
  },
  set: function (value) {
    if (this.length === 0) {
      this.push(value);
    }
    else {
      this[this.length - 1] = value;
    }
  }
});

Array.prototype.reversed = function() {
  return [...this].reverse();
};

Array.prototype.sorted = function(fn) {
  return [...this].sort(fn);
};

Array.prototype.zip = function <T1, T2>(other: T2[]): [T1, T2][] {
  if (this.length > other.length) {
    return other.map((e, i) => [this[i], e]);
  } else {
    return this.map((e, i) => [e, other[i]]);
  }
};
