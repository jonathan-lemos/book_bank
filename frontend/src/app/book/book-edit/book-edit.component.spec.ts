import {ComponentFixture, TestBed} from '@angular/core/testing';
import {FormsModule} from '@angular/forms';
import {RouterTestingModule} from '@angular/router/testing';
import {FaIconLibrary, FontAwesomeModule} from '@fortawesome/angular-fontawesome';

import {BookEditComponent} from './book-edit.component';
import {KeyValueEditorComponent} from './key-value-editor/key-value-editor.component';

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
});
