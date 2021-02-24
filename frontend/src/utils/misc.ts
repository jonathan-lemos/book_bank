export const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

export function mapToList<T>(o: { [key: string]: T }): { key: string, value: T }[] {
  return Object.keys(o).map(key => ({key: key, value: o[key]}));
}
