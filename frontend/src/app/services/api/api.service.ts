import {Injectable} from '@angular/core';
import {Failure, Result, Success} from "../../../utils/functional/result";
import AuthenticateResponse, {AuthenticateResponseSchema,} from "./schemas/authenticate-response";
import AuthenticateRequest from "./schemas/authenticate-request";
import validate from "../../../utils/validator";
import Suggestion, {SuggestionSchema} from "./schemas/suggestion";
import RefreshResponse, {RefreshResponseSchema} from "./schemas/refresh-response";
import Book, {BookSchema} from "./schemas/book";
import UnauthorizedResponse, {UnauthorizedResponseSchema} from "./schemas/unauthorized-response";
import {AuthService} from "../auth.service";
import UploadResponse, { UploadResponseSchema } from './schemas/upload-response';

type ApiResponse = {type: "no response", reason: string} |
  {type: "json response", status: number, response: any} |
  {type: "non json response", status: number, response: string};

type ApiMethod = "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  
type ApiParams = Partial<{
  body: any,
  auth: AuthService,
  onProgress: (progress: number, total: number) => void;

  headers: {[key: string]: string},
}>

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private readonly apiFetch = async (url: string, method: ApiMethod, params: ApiParams) => new Promise<ApiResponse>(resolve => {
    const apiUrl = `${window.location.origin}/${url.replace(/^\/+/, "")}`;
    const xhr = new XMLHttpRequest();
    xhr.open(method, apiUrl, true);

    for (const key in {"Accept": "application/json", ...(params.headers ?? {})}) {
      if (!params.headers.hasOwnProperty(key)) {
        continue;
      }

      xhr.setRequestHeader(key, params.headers[key]);
    }

    if (params.onProgress) {
      xhr.onprogress = e => e.lengthComputable && params.onProgress(e.loaded, e.total);
    }

    xhr.onerror = e => resolve({type: "no response", reason: "Network error"});

    xhr.onreadystatechange = () => {
      if (xhr.readyState !== XMLHttpRequest.DONE) {
        return; 
      }

      const text = xhr.responseText;
      try {
        resolve({ type: "json response", status: xhr.status, response: JSON.parse(text) });
        return;
      }
      catch (e) {
        resolve({ type: "non json response", status: xhr.status, response: text });
        return;
      }
    }

    if (params.body === undefined) {
      xhr.send();
    }
    else if (params.body instanceof FormData) {
      xhr.send(params.body);
    }
    else {
      xhr.setRequestHeader("Content-Type", "application/json");
      xhr.send(JSON.stringify(params.body));
    }
  });

  private postProcess<T>(f: (s: { status: number, response: any }) => Result<T, string>): (a: ApiResponse) => Result<T, string> {
    return (a: ApiResponse) => {
      if (a.type !== "json response") {
        return new Failure(JSON.stringify({ ...a, error: "Expected a JSON response" }, null, 2));
      }

      if (Math.floor(a.status / 100) !== 2) {
        return new Failure(JSON.stringify({ ...a, error: "Response status was not 2XX." }, null, 2));
      }

      return f(a);
    }
  }

  private readonly ajax = (method: ApiMethod, onProgress?: (progress: number, total: number) => void) => async (url: string, auth?: AuthService, onProgress?: (progress: number, total: number) => void) =>
    this.apiFetch(url, method, { auth, onProgress });

  private readonly ajaxBody = (method: ApiMethod, onProgress?: (progress: number, total: number) => void) => async (url: string, body: any, auth?: AuthService, onProgress?: (progress: number, total: number) => void) =>
    this.apiFetch(url, method, { auth, onProgress, body });

  private readonly get = this.ajax("GET");
  private readonly del = this.ajax("DELETE");
  private readonly post = this.ajaxBody("POST");
  private readonly patch = this.ajaxBody("PATCH");
  private readonly put = this.ajaxBody("PUT");

  constructor() { }

  async authenticate(username: string, password: string, auth: AuthService): Promise<Result<void, string>> {
    const resp = await this.post("/api/login", { username, password } as AuthenticateRequest).then(this.postProcess(res => {
      return validate<AuthenticateResponse>(res, AuthenticateResponseSchema);
    }));

    if (resp.isSuccess()) {
      if (resp.value.token === null) {
        return new Failure(`The authentication response did not contain an access token. Was ${JSON.stringify(resp.value)}`);
      }

      return auth.authenticate(resp.value.token).map_val(() => { });
    }
    else {
      return resp.map_val(() => { });
    }
  }

  async book(id: string): Promise<Result<Book, string>> {
    if (id === "") {
      return new Failure("The id cannot be blank.");
    }

    return await this.get(`/api/books/metadata/${id}`).then(this.postProcess(res => {
      return validate(res, BookSchema);
    }))
  }

  async deleteBook(id: string, auth: AuthService): Promise<Result<void, string>> {
    if (id === "") {
      return new Failure("The id cannot be blank.");
    }

    return await this.del(`/api/books/${id}`).then(this.postProcess(_ => new Success(null)));
  }

  async refresh(auth: AuthService): Promise<Result<void, string>> {
    const resp = await this.post("/api/login/refresh", {}).then(this.postProcess(res => {
      return validate<RefreshResponse>(res, RefreshResponseSchema);
    }));

    if (resp.isSuccess()) {
      if (resp.value.token === null) {
        return new Failure("The authentication response did not contain an access token.");
      }

      return auth.authenticate(resp.value.token).map_val(() => { });
    }
    else {
      return resp.map_val(() => { });
    }
  }

  async search(query: string, auth: AuthService, count?: number, page?: number): Promise<Result<Book[], string>> {
    if (query === "") {
      return new Success([]);
    }

    return await this.get(`/api/search/${query}?count=${count}&page=${page}`, auth).then(this.postProcess(res => {
      return validate(res, [BookSchema]);
    }));
  }

  async search_count(query: string, auth: AuthService): Promise<Result<number, string>> {
    if (query === "") {
      return new Success(0);
    }

    return await this.get(`/api/search_count/${query}`, auth).then(this.postProcess(res => {
      const r = validate<number>(res, "number");
      if (r.isSuccess() && r.value < 0) {
        return new Failure(`Search count cannot be below 0 (was ${r.value}).`);
      }
      return r;
    }))
  }

  async suggestions(query: string, auth: AuthService, count?: number): Promise<Result<Suggestion[], string>> {
    if (query === "") {
      return new Success([]);
    }

    return await this.get(`/api/suggestions/${encodeURIComponent(query)}/${count ?? 5}`, auth).then(this.postProcess(res => {
      return validate(res, [SuggestionSchema])
    }));
  }

  async updateBookMetadata(bookId: string, title: string, metadata: { key: string, value: string }[], auth: AuthService): Promise<Result<void, string>> {
    if (bookId === "") {
      return new Failure("The book id cannot be blank");
    }
    return await this.post(`/api/books/metadata/${bookId}`, { title, metadata }, auth).then(this.postProcess(_ => new Success(null)))
  }

  async uploadBook(form: FormData, auth: AuthService, onProgress?: (progress: number, total: number) => void): Promise<Result<string, string>> {
    if (["title", "book", "filename"].some(t => form.get(t) === null)) {
      return new Failure("The form must have 'title', 'book', and 'filename' keys.");
    }

    return await this.post("/api/books", form, auth, onProgress).then(this.postProcess(res => {
      return validate<UploadResponse>(res, UploadResponseSchema).map_val(x => x.id);
    }));
  }
}
