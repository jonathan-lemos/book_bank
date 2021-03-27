import {ComponentFixture, fakeAsync, TestBed, tick} from '@angular/core/testing';
import {RouterTestingModule} from '@angular/router/testing';
import {NavbarComponent} from 'src/app/navbar/navbar.component';

import {SearchComponent} from './search.component';
import {InfiniteScrollModule} from "ngx-infinite-scroll";
import {Result, Success} from "../../../utils/functional/result";
import {BookListingComponent} from "../book-listing/book-listing.component";
import {queryElements, waitForComponentChanges} from "../../../test/dom";
import Book from "../../services/api/schemas/book";

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

  beforeEach(fakeAsync(() => {
    fixture = TestBed.createComponent(SearchComponent);
    component = fixture.componentInstance;
  }));

  const searchResults = [
    {id: "1", title: "Green Eggs and Ham", size: 99, metadata: {author: "Dr. Seuss"}},
    {id: "2", title: "Book", size: 199, metadata: {author: "Dr. Seuss"}}
  ];

  const nextSearchResults = [
    {id: "3", title: "Finding Religion with C++", size: 666, metadata: {author: "Dr. Seuss"}},
    {id: "4", title: "Book2", size: 299, metadata: {author: "Dr. Seuss"}}
  ];

  const searchSpy = (results: Book[][]) => {
    let searchSpy = spyOn(component.api, "search").and.returnValues(
      ...results.map(result => Promise.resolve(new Success(result)) as Promise<Result<Book[], string>>)
    );

    let countSpy = spyOn(component.api, "search_count").and.returnValue(
      Promise.resolve(new Success(
        results.reduce((a, c) => a + c.length, 0))));

    return {
      expectToHaveBeenCalled: () => {
        expect(countSpy).toHaveBeenCalled();
        expect(searchSpy).toHaveBeenCalled();
      },
      entries: results.reduce((a, c) => a.concat(c)),
      expectComponentBooksToEqualSearchResults: function () {
        expect(component.books).toEqual(this.entries);
      }
    }
  };

  const initComponent = () => {
    waitForComponentChanges(fixture);
  };

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should add entries on create', fakeAsync(() => {
    const spy = searchSpy([searchResults]);

    initComponent();

    spy.expectToHaveBeenCalled();
    spy.expectComponentBooksToEqualSearchResults();
  }));

  it('should add more entries on loadMore twice', fakeAsync(() => {
    const spy = searchSpy([searchResults, nextSearchResults]);

    initComponent();
    component.loadMore();
    waitForComponentChanges(fixture);

    spy.expectToHaveBeenCalled();
    spy.expectComponentBooksToEqualSearchResults();
  }));

  it('should display entries', fakeAsync(() => {
    const spy = searchSpy([searchResults, nextSearchResults]);


    initComponent();
    component.loadMore();
    waitForComponentChanges(fixture);

    const elements = queryElements<HTMLElement>(fixture, "app-book-listing");
    expect(elements.length).toEqual(spy.entries.length);

    elements.zip(spy.entries).forEach(([e, c]) => {
      expect(e.innerText).toContain(c.title);
    });
  }));
});
