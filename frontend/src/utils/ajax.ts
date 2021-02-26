import {Failure, Result, Success} from "./functional/result";

export type FetchProgressParams =
  {
    method: "GET" | "POST" | "PATCH" | "PUT" | "DELETE"
  } & Partial<{
  body: FormData | { [key: string]: any },
  auth: string,
  headers: { [key: string]: string }
}>

export interface FetchProgressResult {
  status: number;
  text: string;
}

export interface FetchProgressError {
  status: number;
  reason: string | null;
}

export default function fetchProgress(url: string, params: FetchProgressParams, onprogress?: (progress: number, total: number) => void) {
  return new Promise<Result<FetchProgressResult, FetchProgressError>>((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open(params.method, url, true);

    const headers = params.headers ?? {};
    if (params.auth) {
      headers["Authorization"] = `Bearer ${params.auth}`;
    }

    for (const key in headers) {
      if (!headers.hasOwnProperty(key)) {
        continue;
      }

      xhr.setRequestHeader(key, headers[key]);
    }

    const bodyToObj = () => {
      if (params.body === undefined) {
        return undefined;
      }

      if (params.body instanceof FormData) {
        return params.body;
      }

      xhr.setRequestHeader("Content-Type", "application/json");
      return JSON.stringify(params.body);
    }

    xhr.onprogress = e => {
      onprogress && onprogress(e.loaded, e.total);
    }

    xhr.onreadystatechange = () => {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        const status = xhr.status;
        if (status === 0 || Math.floor(status / 100) === 2) {
          resolve(new Success({status: status, text: xhr.responseText}));
        } else {
          try {
            resolve(new Failure({status: status, reason: xhr.responseText}));
          } catch (e) {
            resolve(new Failure({status: status, reason: null}));
          }
        }
      }
    }

    xhr.send(bodyToObj());
  })
}
