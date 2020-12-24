import { EventEmitter, Injectable } from '@angular/core';
import { CanActivate, NavigationStart, Router } from '@angular/router';
import {Failure, Result, Success} from '../../utils/functional/result';
import { ApiService } from './api/api.service';

@Injectable({
  providedIn: 'root'
})
export class AuthService implements CanActivate {
  _emitter = new EventEmitter<"Login" | "Logout">();
  _username: string | null = null;

  subscribe(fn: (event: "Login" | "Logout") => void) {
    this._emitter.subscribe(fn);
  }

  constructor(private api: ApiService, private router: Router) {
    api.unauthorizedSubscribe(() => {
      if (this.isAuthenticated()) {
        this.logout();
      }
    });

    const auth = this.auth();

    if (auth !== null) {
      try {
        const exp = JSON.parse(atob(auth.split(".")[1])).exp;
        if (exp != null) {
          if (new Date(exp * 1000) < new Date()) {
            console.log("The JWT has expired");
            this.logout();
          }
          else {
            const d = new Date(exp * 1000);
            console.log(`JWT expires at ${d.toLocaleString()}`)
          }
        }
      }
      catch (e) {
        console.log(`Invalid auth token '${auth}'`);
        this.logout();
      }
    }
  }

  canActivate(): boolean {
    if (!this.isAuthenticated()) {
      this.router.navigate(["login"]);
      return false;
    }
    return true;
  }

  isAuthenticated(): boolean {
    return window.localStorage.getItem("Auth") != null;
  }

  auth(): string | null {
    return window.localStorage.getItem("Auth");
  }

  username(): string | null {
    const auth = this.auth();
    if (auth === null) {
      return null;
    }

    try {
      return JSON.parse(atob(auth.split(".")[1])).sub;
    }
    catch (e) {
      console.log(`Invalid auth token '${auth}'`);
      this.logout();
      return null;
    }
  }

  logout(): void {
    window.localStorage.removeItem("Auth");
    document.cookie = "X-Auth-Token=; expires=Thu, 01 Jan 1970 00:00:00 GMT";
    this._username = null;
    this._emitter.emit("Logout");
    this.router.navigate(["login"]);
  }

  async authenticate(username: string, password: string): Promise<Result<string, string>> {
    const res = await this.api.authenticate(username, password);
    return res.match(
      success => {
        if (typeof success.token === "string") {
          window.localStorage.setItem("Auth", success.token);
          this._emitter.emit("Login");
          return new Success(success.token);
        }
        else {
          return new Failure(success.response);
        }
      },
      failure => {
        return new Failure(failure);
      }
    );
  }
}
