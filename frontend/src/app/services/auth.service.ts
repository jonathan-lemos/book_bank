import { Injectable } from '@angular/core';
import {
  CanActivate,
  Router,
} from '@angular/router';
import {Failure, Result, Success} from '../../utils/functional/result';

@Injectable({
  providedIn: 'root'
})
export class AuthService implements CanActivate {
  constructor(private router: Router) {
  }

  authenticate(token: string): Result<AuthenticationContext, string> {
    const res = AuthenticationContext.tryCreate(token);
    if (res.isSuccess()) {
      localStorage.setItem("Auth-sub", res.value.sub);
      localStorage.setItem("Auth-iat", res.value.iat.toISOString());
      localStorage.setItem("Auth-exp", res.value.exp.toISOString());
    }
    return res;
  }

  canActivate() {
    return this.isAuthenticated();
  }

  context(): AuthenticationContext | null {
    try {
      const sub = localStorage.getItem("Auth-sub");
      if (sub === null) {
        return null;
      }
      const iat = new Date(localStorage.getItem("Auth-iat"));
      if (iat.getTime() > Date.now()) {
        return null;
      }
      const exp = new Date(localStorage.getItem("Auth-exp"));
      if (exp.getTime() <= Date.now()) {
        return null;
      }
      return new AuthenticationContext(sub, iat, exp);
    }
    catch (e) {
      return null;
    }
  }

  isAuthenticated(): boolean {
    return this.context() !== null;
  }

  logout() {
    window.localStorage.removeItem("Auth-sub");
    window.localStorage.removeItem("Auth-iat");
    window.localStorage.removeItem("Auth-exp");
    this.router.navigate(["login"]);
  }
}

export class AuthenticationContext {
  private _sub: string;
  private _iat: Date;
  private _exp: Date;

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

    return new Success(new AuthenticationContext(sub, iat, exp));
  }

  constructor(sub: string, iat: Date, exp: Date) {
    this._sub = sub;
    this._iat = iat;
    this._exp = exp
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
