export const size_unit = (n: number): [number, string] => {
  const units = ["TB", "GB", "MB", "KB", "B"]

  if (n <= 0) {
    return [0, "B"]
  }

  while (n > 1024) {
    n /= 1024;
    units.pop();
  }

  return [n, units[units.length - 1]];
}
