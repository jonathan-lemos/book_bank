import {ComponentFixture, TestBed} from '@angular/core/testing';
import {RouterTestingModule} from '@angular/router/testing';

import {NavbarComponent} from './navbar.component';
import {routingEntries} from "../app-routing.module";
import {RoleType} from "../roles";

describe('NavbarComponent', () => {
  let component: NavbarComponent;
  let fixture: ComponentFixture<NavbarComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RouterTestingModule],
      declarations: [NavbarComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(NavbarComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should highlight the correct link', () => {
    spyOn(component.auth, "allowed").and.returnValue(true);
    spyOnProperty(component.router, "url").and.returnValue("/home");
    component.url = "/home";
    fixture.detectChanges();

    component.updateState();

    expect(component.links.some(link => link.active && link.name === "Home")).toBeTrue();
  });

  it('should display the correct links for regular user', () => {
    spyOn(component.auth, "allowed").and.callFake(x => x === RoleType.Authenticated);
    spyOnProperty(component.router, "url").and.returnValue("/home");
    component.url = "/home";

    fixture.detectChanges();

    component.updateState();

    const expectedNames = routingEntries
      .filter(x => x.auth.roles === RoleType.Authenticated && x.auth.putInNavbar)
      .map(x => x.auth.name);

    expect(component.links.map(x => x.name)).toEqual(expectedNames);
  });
});
