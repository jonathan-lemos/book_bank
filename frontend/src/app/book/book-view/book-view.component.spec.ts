import { ComponentFixture, TestBed } from '@angular/core/testing';
import { RouterTestingModule } from '@angular/router/testing';

import { BookViewComponent } from './book-view.component';

describe('BookViewComponent', () => {
  let component: BookViewComponent;
  let fixture: ComponentFixture<BookViewComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RouterTestingModule],
      declarations: [BookViewComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(BookViewComponent);
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
