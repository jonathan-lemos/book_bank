import {AuthenticationContext, AuthService} from "../app/services/auth.service";
import {Failure, Result, Success} from "../utils/functional/result";
import {ApiService} from "../app/services/api/api.service";

export class AuthSpy {
  authenticateSpy: jasmine.Spy<AuthService["authenticate"]>;
  apiAuthenticateSpy: jasmine.Spy<ApiService["authenticate"]>;
  isAuthenticatedSpy: jasmine.Spy<AuthService["isAuthenticated"]>;

  constructor(authService: AuthService, apiService: ApiService, authShouldSucceed: boolean = true) {
    const successfulContext = new AuthenticationContext(
      "admin",
      new Date(Date.now() * 1000 - 10000),
      new Date(Date.now() * 1000 + 10000),
      ["admin"]);


    this.authenticateSpy = spyOn(authService, "authenticate").and.returnValue(new Success(successfulContext));
    this.isAuthenticatedSpy = spyOn(authService, "isAuthenticated").and.callFake(
      () => this.authenticateSpy.calls.any() && authShouldSucceed
    );
    this.apiAuthenticateSpy = spyOn(apiService, "authenticate").and.callFake((_username, _password, _auth): Promise<Result<void, string>> => {
      if (authShouldSucceed) {
        authService.authenticate("foo bar");
        return Promise.resolve(new Success(undefined));
      }
      else {
        return Promise.resolve(new Failure("Mock simulated API authentication failure."));
      }
    })
  }

  expectSuccessfulAuth() {
    expect(this.apiAuthenticateSpy).toHaveBeenCalled();
    expect(this.authenticateSpy).toHaveBeenCalledWith("foo bar");
  }

  expectUnsuccessfulAuth() {
    expect(this.apiAuthenticateSpy).toHaveBeenCalled();
    expect(this.authenticateSpy).not.toHaveBeenCalled();
  }
}

export const spyOnAuthAndSucceed = (object: AuthService) => {
  const actx = new AuthenticationContext(
    "admin",
    new Date(Date.now() * 1000 - 10000),
    new Date(Date.now() * 1000 + 10000),
    ["admin"]);

  return spyOn(object, "authenticate")
    .and.returnValue(new Success(actx));
}
