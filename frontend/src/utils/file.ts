export const fileToBinaryString = (f: File) => new Promise<string>((resolve, reject) => {
  const fr = new FileReader();

  fr.addEventListener("load", () => {
    resolve(fr.result as string);
  });

  fr.addEventListener("error", () => {
    reject(fr.error);
  });

  fr.readAsBinaryString(f);
});
