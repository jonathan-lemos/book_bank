import {Component, OnInit} from '@angular/core';
import {NavigationEnd, Router} from '@angular/router';
import {NavbarRender, routingEntries} from '../app-routing.module';
import {AuthService} from '../services/auth.service';

@Component({
  selector: 'app-navbar',
  templateUrl: './navbar.component.html',
  styleUrls: ['./navbar.component.sass']
})
export class NavbarComponent implements OnInit {
  links: { path: string, name: string, active: boolean }[] = [];
  navbarState: NavbarRender = NavbarRender.Hidden;

  get navbarClass() {
    switch (this.navbarState) {
      case NavbarRender.Normal:
        return "normal";
      case NavbarRender.Fixed:
        return "fixed";
      default:
        return "hidden";
    }
  }

  url: string = "";

  constructor(public auth: AuthService, public router: Router) {
  }

  ngOnInit(): void {
    this.url = this.router.url;
    this.updateState.bind(this)();

    this.router.events.subscribe(val => {
      if (!(val instanceof NavigationEnd)) {
        return;
      }
      this.url = val.urlAfterRedirects;
      this.updateState.bind(this)();
    });

    this.auth.subscribe(this.updateState.bind(this));
  }

  updateState(): void {
    this.links = routingEntries
      .filter(x => x.auth && x.auth.putInNavbar && x.auth.roles && this.auth.allowed(x.auth.roles))
      .map(x => {
        const currentIsActive = this.url.replace(/^\//, "").startsWith(x.route.path);

        if (currentIsActive) {
          this.navbarState = x.auth.navbarRender;
        }

        return {
          path: x.route.path.replace(/^(?!\/)/, "/"),
          name: x.auth.name,
          active: currentIsActive
        }
      });
  }
}
