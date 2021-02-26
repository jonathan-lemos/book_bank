import {ComponentFixture, TestBed} from '@angular/core/testing';
import {FormsModule} from '@angular/forms';
import {RouterTestingModule} from '@angular/router/testing';

import {LoginComponent} from './login.component';
import {routes} from "../app-routing.module";
import {AuthSpy} from "../../test/auth_spy";

describe('LoginComponent', () => {
  let component: LoginComponent;
  let fixture: ComponentFixture<LoginComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RouterTestingModule.withRoutes(routes), FormsModule],
      declarations: [LoginComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(LoginComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should login on successful response', async () => {
    const authSpy = new AuthSpy(component.auth, component.api);
    const routerSpy = spyOn(component.router, 'navigate').and.returnValue(Promise.resolve(true));

    await component.login();
    authSpy.expectSuccessfulAuth();
    expect(routerSpy).toHaveBeenCalledWith(["/home"]);
  });

  it('should not login on unsuccessful response', async () => {
    const authSpy = new AuthSpy(component.auth, component.api, false);
    const routerSpy = spyOn(component.router, 'navigate').and.returnValue(Promise.resolve(true));

    await component.login();
    authSpy.expectUnsuccessfulAuth();
    expect(routerSpy).not.toHaveBeenCalledWith(["/home"]);
  });
});
