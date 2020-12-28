export const round = (n: number, dp: number = 2): string => {
  return n.toFixed(dp).replace(/\.?0+$/, "");
}
