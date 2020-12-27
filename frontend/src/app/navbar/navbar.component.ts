import { Component, OnInit } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';
import { routes } from '../app-routing.module';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-navbar',
  templateUrl: './navbar.component.html',
  styleUrls: ['./navbar.component.sass']
})
export class NavbarComponent implements OnInit {
  links = routes.filter(x => x.putInNavbar && (x.canActivate == null || this.auth.isAuthenticated()));

  active: string;

  constructor(public auth: AuthService, public router: Router) {
    auth.subscribe(ev => this.links = routes.filter(x => x.putInNavbar && (auth.isAuthenticated() || x.canActivate == null)));
  }

  ngOnInit(): void {
    this.active = this.router.url;

    this.router.events.subscribe(val => {
      if (!(val instanceof NavigationEnd)) {
        return;
      }
      this.active = val.urlAfterRedirects;
    });
  }
}
