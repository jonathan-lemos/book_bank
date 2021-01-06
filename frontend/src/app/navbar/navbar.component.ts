import {Component, OnInit} from '@angular/core';
import {Router} from '@angular/router';
import {routes} from '../app-routing.module';
import {AuthService} from '../services/auth.service';

@Component({
  selector: 'app-navbar',
  templateUrl: './navbar.component.html',
  styleUrls: ['./navbar.component.sass']
})
export class NavbarComponent implements OnInit {
  links: {path: string, name: string}[];

  constructor(public auth: AuthService, public router: Router) {
  }

  private updateState(): void {
    this.links = routes.filter(x => x.putInNavbar && this.auth.allowed(x.roles));
  }

  ngOnInit(): void {
    this.updateState();
  }
}
