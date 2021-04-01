import {AfterViewInit, Component, ElementRef, OnInit, ViewChild} from '@angular/core';
import {ApiService} from "../services/api/api.service";
import {AuthService} from "../services/auth.service";
import {ActivatedRoute, Router} from "@angular/router";
import {TextInputComponent} from "../form/text-input/text-input.component";

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.sass']
})
export class LoginComponent implements OnInit, AfterViewInit {
  username: string = "";
  password: string = "";
  error: string = "";

  @ViewChild("usernameInput") usernameRef: TextInputComponent | null = null;
  @ViewChild("passwordInput") passwordRef: TextInputComponent | null = null;

  constructor(public api: ApiService, public auth: AuthService, public router: Router, private av: ActivatedRoute) {
  }

  ngOnInit(): void {
    if (this.auth.isAuthenticated() !== null) {
      this.router.navigate(["/home"]).catch(console.error);
    }

    this.username = this.av.snapshot.paramMap.get("username") ?? "";
  }

  ngAfterViewInit(): void {
    this.focusUsername.bind(this)();
  }

  focusUsername(): void {
    this.usernameRef?.focusInput();
  }

  focusPassword(): void {
    this.passwordRef?.focusInput();
  }

  async login(): Promise<void> {
    const res = await this.api.authenticate(this.username, this.password, this.auth);
    res.match(
      _ => {
        this.router.navigate(["/home"]).catch(console.error);
      },
      failure => {
        this.error = failure;
      }
    );
  }
}
