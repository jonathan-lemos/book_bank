import {Component, OnInit, ViewChild} from '@angular/core';
import {TextInputComponent} from "../form/text-input/text-input.component";
import {ApiService} from "../services/api/api.service";
import {AuthService} from "../services/auth.service";
import {ActivatedRoute, Router} from "@angular/router";

@Component({
  selector: 'app-create-account',
  templateUrl: './create-account.component.html',
  styleUrls: ['./create-account.component.sass']
})
export class CreateAccountComponent implements OnInit {
  username: string = "";
  password: string = "";
  confirmPassword: string = "";
  error: string = "";

  @ViewChild("usernameInput") usernameRef: TextInputComponent | null = null;
  @ViewChild("passwordInput") passwordRef: TextInputComponent | null = null;
  @ViewChild("confirmPasswordInput") confirmPasswordRef: TextInputComponent | null = null;

  constructor(public api: ApiService, public auth: AuthService, public router: Router, private av: ActivatedRoute) {
  }

  createAccountText() {
    return `[create ${this.username}]`;
  }

  fieldsAreValid() {
    return this.username !== "" && this.password !== "" && this.password === this.confirmPassword;
  }

  ngOnInit(): void {
    if (this.auth.isAuthenticated()) {
      this.router.navigate(["/home"]).catch(console.error);
    }

    this.username = this.av.snapshot.paramMap.get("username") ?? "pussyslayer69";
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

  focusConfirmPassword(): void {
    this.confirmPasswordRef?.focusInput();
  }

  navigateToLogin(): void {
    this.router.navigate(["/login"]).catch(console.error);
  }

  async createAccount(): Promise<void> {
    if (!this.fieldsAreValid()) {
      return;
    }

    const res = await this.api.createAccount(this.username, this.password);
    res.match(
      _ => {
        this.navigateToLogin();
      },
      failure => {
        this.error = failure;
      }
    );
  }
}
