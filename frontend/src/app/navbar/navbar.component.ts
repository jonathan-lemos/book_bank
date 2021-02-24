import {Component, OnInit} from '@angular/core';
import {ActivatedRoute, NavigationEnd, Router} from '@angular/router';
import {routingEntries} from '../app-routing.module';
import {AuthService} from '../services/auth.service';

@Component({
  selector: 'app-navbar',
  templateUrl: './navbar.component.html',
  styleUrls: ['./navbar.component.sass']
})
export class NavbarComponent implements OnInit {
  links: { path: string, name: string, active: boolean }[];

  url: string;

  constructor(public auth: AuthService, public router: Router, private route: ActivatedRoute) {
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

  private updateState(): void {
    const entries = routingEntries
      .filter(x => x.auth && x.auth.putInNavbar && x.auth.roles && this.auth.allowed(x.auth.roles))
      .map(x => ({
        path: x.route.path,
        name: x.auth.name,
        active: this.url.replace(/^\//, "").startsWith(x.route.path)
      }));

    this.links = entries;
  }
}
