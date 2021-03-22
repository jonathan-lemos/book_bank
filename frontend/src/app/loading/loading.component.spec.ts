import {ComponentFixture, fakeAsync, flush, TestBed, tick} from '@angular/core/testing';

import {LoadingComponent} from './loading.component';
import {queryElement} from "../../test/dom";
import {Failure, Result, Success} from "../../utils/functional/result";
import {FontAwesomeModule} from "@fortawesome/angular-fontawesome";

describe('LoadingComponent', () => {
  let component: LoadingComponent;
  let fixture: ComponentFixture<LoadingComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [FontAwesomeModule],
      declarations: [LoadingComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(LoadingComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should display non loading without a promise', () => {
    component.promise = null;
    fixture.detectChanges();

    const inner = queryElement(fixture, ".inner.not-loading");
    expect(inner).toBeTruthy();
  });

  it('should display loading with an unresolved promise', () => {
    // everlasting promise
    component.promise = new Promise<Result<string, string>>(() => {
    });
    fixture.detectChanges();

    const inner = queryElement(fixture, ".inner.loading");
    expect(inner).toBeTruthy();
  });

  it('should display success with a successful promise', fakeAsync(() => {
    component.promise = Promise.resolve(new Success("MOCK success"));
    tick();
    fixture.detectChanges();

    const successElement = queryElement(fixture, "b.success");
    const failureElement = queryElement(fixture, "b.error");
    const body = queryElement(fixture, ".body");
    expect(successElement).toBeTruthy();
    expect(failureElement).not.toBeTruthy();
    expect(body?.innerText).toBe("MOCK success");

    flush();
  }));

  it('should display failure with a failing promise', fakeAsync(() => {
    component.promise = Promise.resolve(new Failure("MOCK failure"));
    tick();
    fixture.detectChanges();

    const innerSuccess = queryElement(fixture, "b.success");
    const innerFailure = queryElement(fixture, "b.error");
    const body = queryElement(fixture, ".body");
    expect(innerSuccess).not.toBeTruthy();
    expect(innerFailure).toBeTruthy();
    expect(body?.innerText).toBe("MOCK failure");

    flush();
  }));
});
