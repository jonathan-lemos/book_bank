export const sizeUnit = (n: number): [number, string] => {
  const units = ["TB", "GB", "MB", "KB", "B"]

  if (n <= 0) {
    return [0, "B"]
  }

  while (n > 1000) {
    n /= 1000;
    units.pop();
  }

  return [n, units[units.length - 1]];
}
