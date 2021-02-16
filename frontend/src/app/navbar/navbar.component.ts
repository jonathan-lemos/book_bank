import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { routingEntries } from '../app-routing.module';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-navbar',
  templateUrl: './navbar.component.html',
  styleUrls: ['./navbar.component.sass']
})
export class NavbarComponent implements OnInit {
  links: { path: string, name: string }[];

  constructor(public auth: AuthService, public router: Router) {
  }

  private updateState(): void {
    this.links = routingEntries
      .filter(x => x.auth && x.auth?.putInNavbar && x.auth?.roles && this.auth.allowed(x.auth?.roles))
      .map(x => ({ path: x.route.path, name: x.auth.name }));
  }

  ngOnInit(): void {
    this.updateState();
  }
}
