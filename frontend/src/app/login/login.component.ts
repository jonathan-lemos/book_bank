import {Component, OnInit} from '@angular/core';
import {ApiService} from "../services/api/api.service";
import {AuthService} from "../services/auth.service";
import {ActivatedRoute, Router} from "@angular/router";

@Component({
  selector: 'app-login',
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.sass']
})
export class LoginComponent implements OnInit {
  username: string = "";
  password: string = "";
  error: string = "";

  constructor(private api: ApiService, private auth: AuthService, private router: Router, private av: ActivatedRoute) { }

  ngOnInit(): void {
    if (this.auth.isAuthenticated() !== null) {
      this.router.navigate(["home"]).catch(console.log);
    }

    this.username = this.av.snapshot.paramMap.get("username") ?? "";
  }

  async login(): Promise<void> {
    const res = await this.api.authenticate(this.username, this.password, this.auth);
    res.match(
      _ => {
        this.router.navigate(["home"]);
      },
      failure => {
        this.error = failure;
      }
    );
  }

  async keydown(e: KeyboardEvent): Promise<void> {
    if (e.key === "Enter") {
      await this.login();
    }
  }
}
