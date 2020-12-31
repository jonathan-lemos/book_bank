import { EventEmitter, Injectable } from '@angular/core';
import {Failure, Result, Success} from "../../../utils/functional/result";
import AuthenticateResponse, {
  AuthenticateResponseSchema,
} from "./schemas/authenticate-response";
import AuthenticateRequest from "./schemas/authenticate-request";
import validate from "../../../utils/validator";
import Suggestion, {SuggestionSchema} from "./schemas/suggestion";
import RefreshResponse, {RefreshResponseSchema} from "./schemas/refresh-response";
import Book, {BookSchema} from "./schemas/book";
import UnauthorizedResponse, {UnauthorizedResponseSchema} from "./schemas/unauthorized-response";
import {AuthService} from "../auth.service";

type ApiResponse = {type: "no response", reason: string} |
  {type: "json response", status: number, response: any} |
  {type: "non json response", status: number, response: string};


@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private readonly apiFetch = async (url: string, params: RequestInit, auth?: AuthService, retryUnauthorized = true): Promise<ApiResponse> => {
    url = `${window.location.origin}/${url.replace(/^\/+/, "")}`;
    try {
      let res1 = await fetch(url, params);

      const text = await res1.text();
      try {
        const res2 = text.trim() !== "" ? JSON.parse(text) : "";

        const check = validate<UnauthorizedResponse>(res2, UnauthorizedResponseSchema);

        if (retryUnauthorized && res1.status === 401 && check.isSuccess() && auth !== undefined) {
          if (check.value.reason === "expired token") {
            const res = await this.refresh(auth);
            if (res.isError()) {
              console.log(`Failed to refresh token: ${res.value}`);
            }
            else {
              return await this.apiFetch(url, params, auth, false);
            }
          }
          return await this.apiFetch(url, params, auth, false);
        }

        return {type: "json response", status: res1.status, response: res2};
      }
      catch (e) {
        return {type: "non json response", status: res1.status, response: text};
      }
    }
    catch (e) {
      return {type: "no response", reason: e.message ?? e};
    }
  }

  private postProcess<T>(f: (s: {status: number, response: any}) => Result<T, string>): (a: ApiResponse) => Result<T, string> {
    return (a: ApiResponse) => {
      if (a.type !== "json response") {
        return new Failure(JSON.stringify({...a, error: "Expected a JSON response"}, null, 2));
      }

      if (Math.floor(a.status / 100) !== 2) {
        return new Failure(JSON.stringify({...a, error: "Response status was not 2XX."}, null, 2));
      }

      return f(a);
    }
  }

  private readonly ajax = (method: string) => async (url: string, auth?: AuthService) =>
    this.apiFetch(url, {
      method: method,
      credentials: "include"
    }, auth);

  private readonly ajaxBody = (method: string) => async (url: string, body: any, auth?: AuthService) =>
    this.apiFetch(url, {
      method: method,
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body)
    }, auth);

  private readonly get = this.ajax("GET");
  private readonly del = this.ajax("DELETE");
  private readonly post = this.ajaxBody("POST");
  private readonly patch = this.ajaxBody("PATCH");

  constructor() { }

  async authenticate(username: string, password: string, auth: AuthService): Promise<Result<void, string>> {
    const resp = await this.post("/api/login", { username, password } as AuthenticateRequest).then(this.postProcess(res => {
      return validate<AuthenticateResponse>(res, AuthenticateResponseSchema);
    }));

    if (resp.isSuccess()) {
      if (resp.value.token === null) {
        return new Failure(`The authentication response did not contain an access token. Was ${JSON.stringify(resp.value)}`);
      }

      return auth.authenticate(resp.value.token).map_val(() => {});
    }
    else {
      return resp.map_val(() => {});
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

      return auth.authenticate(resp.value.token).map_val(() => {});
    }
    else {
      return resp.map_val(() => {});
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

  async updateBookMetadata(bookId: string, title: string, metadata: {key: string, value: string}[], auth: AuthService): Promise<Result<void, string>> {
    if (bookId === "") {
      return new Failure("The book id cannot be blank");
    }
    return await this.post(`/api/books/metadata/${bookId}`, {title, metadata}, auth).then(this.postProcess(_ => new Success(null)))
  }
}
