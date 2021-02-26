import {ComponentFixture, fakeAsync, TestBed, tick} from '@angular/core/testing';
import {FormsModule} from '@angular/forms';
import {RouterTestingModule} from '@angular/router/testing';
import {FaIconLibrary, FontAwesomeModule} from '@fortawesome/angular-fontawesome';

import {BookEditComponent} from './book-edit.component';
import {KeyValueEditorComponent} from './key-value-editor/key-value-editor.component';
import {elementExists, queryElement} from "../../../test/utils";
import {query} from "@angular/animations";

describe('BookEditComponent', () => {
  let component: BookEditComponent;
  let fixture: ComponentFixture<BookEditComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RouterTestingModule, FontAwesomeModule, FormsModule],
      declarations: [BookEditComponent, KeyValueEditorComponent],
      providers: [FaIconLibrary]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(BookEditComponent);

    component = fixture.componentInstance;
    component.book = {
      id: "1",
      title: "Green Eggs and Ham",
      metadata: {
        author: "Dr. Seuss",
        isbn: "0123456789",
      },
      size: 69
    };

    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should emit cancel on cancel', fakeAsync(() => {
    const spy = spyOn(component.cancel, "emit").and.returnValue(undefined);

    queryElement(fixture, ".cancel")!.click();
    tick();

    expect(spy).toHaveBeenCalled();
  }));

  it('should emit delete on delete if admin', fakeAsync(() => {
    const spy = spyOn(component.del, "emit").and.returnValue(undefined);
    spyOn(component.auth, "hasRole").and.returnValue(true);

    fixture.detectChanges();

    queryElement(fixture, ".delete")!.click();
    tick();
    fixture.detectChanges();
    tick();
    queryElement(fixture, ".confirm-delete")!.click();
    tick();

    expect(spy).toHaveBeenCalled();
  }));

  it('should cancel on cancel delete', fakeAsync(() => {
    const spy = spyOn(component.del, "emit").and.returnValue(undefined);
    spyOn(component.auth, "hasRole").and.returnValue(true);

    fixture.detectChanges();

    queryElement(fixture, ".delete")!.click();
    tick();
    fixture.detectChanges();
    tick();
    queryElement(fixture, ".cancel-delete")!.click();
    tick();

    expect(spy).not.toHaveBeenCalled();
    expect(component.confirm_delete).toBe(false);
  }));

  it('should not have cancel button if not admin', fakeAsync(() => {
    spyOn(component.auth, "hasRole").and.returnValue(false);

    fixture.detectChanges();

    expect(elementExists(fixture, ".delete")).toBe(false);
  }));
});
