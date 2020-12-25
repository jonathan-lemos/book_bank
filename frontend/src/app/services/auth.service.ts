import { EventEmitter, Injectable } from '@angular/core';
import { CanActivate, NavigationStart, Router } from '@angular/router';
import {Failure, Result, Success} from '../../utils/functional/result';
import { ApiService } from './api/api.service';

@Injectable({
  providedIn: 'root'
})
export class AuthService implements CanActivate {
  _emitter = new EventEmitter<"Login" | "Logout">();

  subscribe(fn: (event: "Login" | "Logout") => void) {
    this._emitter.subscribe(fn);
  }


}
