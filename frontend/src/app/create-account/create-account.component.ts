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

  focusConfirmPassword(): void {
    this.confirmPasswordRef?.focusInput();
  }

  async createAccount(): Promise<void> {
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
