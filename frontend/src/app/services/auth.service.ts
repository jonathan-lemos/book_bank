import {Injectable} from '@angular/core';
import {ActivatedRouteSnapshot, CanActivate, Router,} from '@angular/router';
import {Failure, Result, Success} from '../../utils/functional/result';
import {Roles, RoleType} from "../roles";

@Injectable({
  providedIn: 'root'
})
export class AuthService implements CanActivate {
  constructor(private router: Router) {
  }

  allowed(roles: Roles): boolean {
    if (roles === RoleType.Any) {
      return true;
    }
    if (roles === RoleType.Unauthenticated) {
      return !this.isAuthenticated();
    }
    if (roles === RoleType.Authenticated) {
      return this.isAuthenticated();
    }
    return this.hasRole(...roles);
  }

  authenticate(token: string): Result<AuthenticationContext, string> {
    const res = AuthenticationContext.tryCreate(token);
    if (res.isSuccess()) {
      localStorage.setItem("Auth-sub", res.value.sub);
      localStorage.setItem("Auth-iat", res.value.iat.toISOString());
      localStorage.setItem("Auth-exp", res.value.exp.toISOString());
      localStorage.setItem("Auth-roles", res.value.roles.join(","));
    }
    return res;
  }

  canActivate(av: ActivatedRouteSnapshot) {
    if (av.data?.roles == null) {
      return true;
    }

    const roles: Roles = av.data.roles;
    if (this.allowed(roles)) {
      return true;
    }
    if (this.isAuthenticated()) {
      return this.router.parseUrl("/home");
    }
    else {
      return this.router.parseUrl("/login");
    }
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
      const roles = localStorage.getItem("Auth-roles").split(",");
      return new AuthenticationContext(sub, iat, exp, roles);
    }
    catch (e) {
      return null;
    }
  }

  hasRole(...roles: string[]): boolean {
    const ctx = this.context();
    if (ctx === null) {
      return false;
    }
    return roles.some(r => ctx.roles.includes(r));
  }

  isAuthenticated(): boolean {
    return this.context() !== null;
  }

  logout() {
    window.localStorage.removeItem("Auth-sub");
    window.localStorage.removeItem("Auth-iat");
    window.localStorage.removeItem("Auth-exp");
    window.localStorage.removeItem("Auth-roles");
    this.router.navigate(["login"]);
  }
}

export class AuthenticationContext {
  public readonly sub: string;
  public readonly iat: Date;
  public readonly exp: Date;
  public readonly roles: string[];

  public static tryCreate(token: string): Result<AuthenticationContext, string> {
    const components = token.split(".");
    if (components.length !== 3) {
      return new Failure(`Malformed JWT. Expected 3 components, got ${components.length}.`);
    }

    let object;
    try {
      object = JSON.parse(atob(components[1]));
    }
    catch (e) {
      return new Failure("Malformed JWT. Expected a base64-encoded object.");
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

    if (!object.hasOwnProperty("roles")) {
      return new Failure("Malformed JWT. Expected a 'roles' field in the body.");
    }
    if (!Array.isArray(object.roles)) {
      return new Failure("Malformed JWT. Expected the 'roles' field to be an array of strings.");
    }

    return new Success(new AuthenticationContext(sub, iat, exp, object.roles.map(x => x.toString())));
  }

  constructor(sub: string, iat: Date, exp: Date, roles: string[]) {
    this.sub = sub;
    this.iat = iat;
    this.exp = exp;
    this.roles = roles;
  }

  isExpired() {
    return Date.now() >= this.exp.getTime();
  }
}
