import {ComponentFixture, TestBed} from '@angular/core/testing';

import {BookListingComponent} from './book-listing.component';
import {RouterTestingModule} from "@angular/router/testing";

describe('BookListingComponent', () => {
  let component: BookListingComponent;
  let fixture: ComponentFixture<BookListingComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RouterTestingModule],
      declarations: [BookListingComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(BookListingComponent);
    component = fixture.componentInstance;
    component.book = {
      id: "1",
      title: "Green Eggs and Ham",
      metadata: {
        author: "Dr. Seuss",
        isbn: "0123456789"
      },
      size: 69
    }
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
