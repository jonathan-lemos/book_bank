import {ComponentFixture, fakeAsync, TestBed, tick} from '@angular/core/testing';
import {RouterTestingModule} from '@angular/router/testing';
import {NavbarComponent} from 'src/app/navbar/navbar.component';

import {SearchComponent} from './search.component';
import {InfiniteScrollModule} from "ngx-infinite-scroll";
import {Success} from "../../../utils/functional/result";
import {BookListingComponent} from "../book-listing/book-listing.component";

describe('SearchComponent', () => {
  let component: SearchComponent;
  let fixture: ComponentFixture<SearchComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RouterTestingModule, InfiniteScrollModule],
      declarations: [SearchComponent, NavbarComponent, BookListingComponent]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(SearchComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should add entries on create', fakeAsync(() => {
    const entries = [
      {id: "1", title: "Green Eggs and Ham", size: 99, metadata: {author: "Dr. Seuss"}},
      {id: "2", title: "Book", size: 199, metadata: {author: "Dr. Seuss"}}
    ]

    const spySearchCount = spyOn(component.api, "search_count").and.returnValue(Promise.resolve(new Success(entries.length)));
    const spySearch = spyOn(component.api, "search").and.returnValue(Promise.resolve(new Success(entries)));

    component.ngOnInit();
    tick();
    fixture.detectChanges();
    tick();

    expect(spySearchCount).toHaveBeenCalled();
    expect(spySearch).toHaveBeenCalled();
    expect(component.books).toEqual(entries);
  }));
});
