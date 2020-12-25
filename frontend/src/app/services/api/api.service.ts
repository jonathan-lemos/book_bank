import { EventEmitter, Injectable } from '@angular/core';
import {Failure, Result, Success} from "../../../utils/functional/result";
import AuthenticateResponse, {
  AuthenticateResponseSchema,
} from "./schemas/authenticate-response";
import AuthenticateRequest from "./schemas/authenticate-request";
import validate from "../../../utils/validator";
import Suggestion, {SuggestionSchema} from "./schemas/suggestion";
import RefreshRequest from "./schemas/refresh-request";
import {RefreshResponseSchema} from "./schemas/refresh-response";
import Book, {BookSchema} from "./schemas/book";
import {CanActivate, Router} from "@angular/router";

type ApiResponse = {type: "no response", reason: string} |
  {type: "json response", status: number, response: any} |
  {type: "non json response", status: number, response: string};

const apiFetch = async (url: string, params: RequestInit): Promise<ApiResponse> => {
  url = `${window.location.origin}/${url.replace(/^\/+/, "")}`;
  try {
    const res1 = await fetch(url, params);

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

function postProcess<T>(f: (s: {status: number, response: any}) => Result<T, string>): (a: ApiResponse) => Result<T, string> {
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

const ajax = (method: string) => async (url: string, auth?: string) =>
  apiFetch(url, {
    method: method,
    credentials: "include",
    headers: {
      "Authorization": auth ? `Bearer ${auth}` : undefined
    }
  });

const ajaxBody = (method: string) => async (url: string, body: any, auth?: string) =>
  apiFetch(url, {
    method: method,
    credentials: "include",
    headers: {
      "Content-Type": "application/json",
      "Authorization": auth ? `Bearer ${auth}` : undefined,
    },
    body: JSON.stringify(body)
  });

const get = this.ajax("GET");
const del = this.ajax("DELETE");
const post = this.ajaxBody("POST");
const patch = this.ajaxBody("PATCH");


@Injectable({
  providedIn: 'root'
})
export class ApiService implements CanActivate {
  private auth_ctx: AuthenticationContext | null = null;

  constructor() { }

  async authenticate(username: string, password: string): Promise<Result<AuthenticationContext, string>> {
    const token = await this.post("/api/login", { username, password } as AuthenticateRequest).then(this.postProcess(res => {
      return validate(res, AuthenticateResponseSchema);
    }));


  }

  async book(id: string): Promise<Result<Book, string>> {
    if (id === "") {
      return new Failure("The id cannot be blank.");
    }

    return await this.get(`/api/book/${id}`).then(this.postProcess(res => {
      return validate(res, BookSchema);
    }))
  }

  async refresh(auth: string): Promise<Result<AuthenticateResponse, string>> {
    return await this.post("/api/login/refresh", {old_token: auth} as RefreshRequest).then(this.postProcess(res => {
      return validate(res, RefreshResponseSchema);
    }));
  }

  async search(query: string, auth: string, count?: number, page?: number): Promise<Result<Book[], string>> {
    if (query === "") {
      return new Success([]);
    }

    return await this.get(`/api/search/${query}`, auth).then(this.postProcess(res => {
      return validate(res, [BookSchema]);
    }));
  }

  async suggestions(query: string, auth: string, count?: number): Promise<Result<Suggestion[], string>> {
    if (query === "") {
      return new Success([]);
    }

    return await this.get(`/api/suggestions/${encodeURIComponent(query)}/${count ?? 5}`, auth).then(this.postProcess(res => {
      return validate(res, [SuggestionSchema])
    }));
  }
}

export class AuthenticationContext {
  _token: string;
  _sub: string;
  _iat: Date;
  _exp: Date;

  public static tryCreate(token: string): Result<AuthenticationContext, string> {
    const components = token.split(".");
    if (components.length !== 3) {
      return new Failure(`Malformed JWT. Expected 3 components, got ${components.length}.`);
    }

    let object;
    try {
      object = atob(components[1]);
    }
    catch (e) {
      return new Failure("Malformed JWT. Expected a base64 body.");
    }

    if (!object.hasOwnProperty("sub")) {
      return new Failure("Malformed JWT. Expected a 'sub' field in the body.");
    }
    const sub = object.sub;
    if (typeof sub !== "string") {
      return new Failure("Malformed JWT. Expected 'sub' to be a string.");
    }


    if (!object.hasOwnProperty("iat")) {
      return new Failure("Malformed JWT. Expected a 'iat' field in the body.");
    }
    const iat_num = object.iat;
    if (typeof iat_num !== "number") {
      return new Failure("Malformed JWT. Expected 'iat' to be a number.");
    }

    let iat: Date;
    try {
      iat = new Date(iat_num * 1000);
    }
    catch (e) {
      return new Failure(`Malformed JWT. 'iat' of ${iat_num} does not represent a valid UNIX time.`);
    }
    if (iat.getTime() > Date.now()) {
      return new Failure(`Malformed JWT. 'iat' of ${iat} is in the future.`);
    }


    if (!object.hasOwnProperty("exp")) {
      return new Failure("Malformed JWT. Expected a 'exp' field in the body.");
    }
    const exp_num = object.exp;
    if (typeof exp_num !== "number") {
      return new Failure("Malformed JWT. Expected 'exp' to be a number.");
    }

    let exp: Date;
    try {
      exp = new Date(exp_num * 1000);
    }
    catch (e) {
      return new Failure(`Malformed JWT. 'exp' of ${exp_num} does not represent a valid UNIX time.`);
    }
    if (exp.getTime() <= Date.now()) {
      return new Failure(`Malformed JWT. 'exp' of ${exp} is in the past. The token has expired.`);
    }

    return new Success(new AuthenticationContext(token, sub, iat, exp));
  }

  private constructor(sub: string, iat: Date, exp: Date) {
    this._sub = sub;
    this._iat = iat;
    this._exp = exp
  }

  get token() {
    return this._token;
  }

  get sub() {
    return this._sub;
  }

  get iat() {
    return this._iat;
  }

  get exp() {
    return this._exp;
  }

  isExpired() {
    return Date.now() >= this._exp.getTime();
  }
}
