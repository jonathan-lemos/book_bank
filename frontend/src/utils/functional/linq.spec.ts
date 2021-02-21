import {flatten, range} from "./linq";

describe("linq", () => {
  it("should flatten", () => {
    const expected = [1, 2, 3, 4, 5, 6, 7, 8];
    const actual = flatten([1, [2, 3, [4, 5]], [], 6, [7, [[8]]]]);
    expect(expected).toEqual(actual);
  });

  it("should range", () => {
    expect(range(5)).toEqual([0, 1, 2, 3, 4]);
    expect(range(2, 5)).toEqual([2, 3, 4]);
    expect(range(2, 10, 2)).toEqual([2, 4, 6, 8]);
    expect(range(5, 2)).toEqual([5, 4, 3]);
    expect(range(5, 2, -2)).toEqual([5, 3]);
  });
});
