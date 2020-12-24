import { EventEmitter, Injectable } from '@angular/core';
import {Failure, Result, Success} from "../../../utils/functional/result";
import AuthenticateResponse, {
  AuthenticateResponseSchema,
} from "./schemas/authenticate-response";
import AuthenticateRequest from "./schemas/authenticate-request";
import validate from "../../../utils/validator";
import Suggestion, {SuggestionSchema} from "./schemas/suggestion";


type ApiResponse = {type: "no response", reason: string} |
  {type: "json response", status: number, response: any} |
  {type: "non json response", status: number, response: string};


@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private unauthorizedListeners: (() => void)[] = []

  constructor() { }

  unauthorizedSubscribe(fn: () => void) {
    this.unauthorizedListeners.push(fn);
  }

  private emitUnauthorized() {
    this.unauthorizedListeners.forEach(x => x());
  }

  private apiFetch = async (url: string, params: RequestInit): Promise<ApiResponse> => {
    url = `${window.location.origin}/${url.replace(/^\/+/, "")}`;
    try {
      const res1 = await fetch(url, params);

      if (res1.status === 401) {
        this.emitUnauthorized();
      }

      const text = await res1.text();
      try {
        const res2 = text.trim() !== "" ? JSON.parse(text) : "";
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

  private ajax = (method: string) => async (url: string, auth?: string) =>
    this.apiFetch(url, {
      method: method,
      credentials: "include",
      headers: {
        "Authorization": auth ? `Bearer ${auth}` : undefined
      }
    });

  private ajaxBody = (method: string) => async (url: string, body: any, auth?: string) =>
    this.apiFetch(url, {
      method: method,
      credentials: "include",
      headers: {
        "Content-Type": "application/json",
        "Authorization": auth ? `Bearer ${auth}` : undefined,
      },
      body: JSON.stringify(body)
    });

  private readonly get = this.ajax("GET");
  private readonly del = this.ajax("DELETE");
  private readonly post = this.ajaxBody("POST");
  private readonly patch = this.ajaxBody("PATCH");

  async authenticate(username: string, password: string): Promise<Result<AuthenticateResponse, string>> {
    return await this.post("/api/login", { username, password } as AuthenticateRequest).then(this.postProcess(res => {
      return validate(res, AuthenticateResponseSchema);
    }));
  }

  async suggestions(query: string, auth: string, count?: number): Promise<Result<Suggestion[], string>> {
    return await this.get(`/api/suggestions/${encodeURIComponent(query)}/${count ?? 5}`, auth).then(this.postProcess(res => {
      return validate(res, [SuggestionSchema])
    }));
  }
}
