import {ComponentFixture, fakeAsync, TestBed, tick} from '@angular/core/testing';
import {RouterTestingModule} from '@angular/router/testing';
import {NavbarComponent} from 'src/app/navbar/navbar.component';

import {SearchComponent} from './search.component';
import {InfiniteScrollModule} from "ngx-infinite-scroll";
import {Success} from "../../../utils/functional/result";
import {BookListingComponent} from "../book-listing/book-listing.component";
import {queryElements} from "../../../test/dom";
import {zip} from "../../../utils/functional/linq";

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

  it('should add more entries on loadMore twice', fakeAsync(() => {
    const entries = [
      {id: "1", title: "Green Eggs and Ham", size: 99, metadata: {author: "Dr. Seuss"}},
      {id: "2", title: "Book", size: 199, metadata: {author: "Dr. Seuss"}}
    ];

    const nextEntries = [
      {id: "3", title: "Finding Religion with C++", size: 666, metadata: {author: "Dr. Seuss"}},
      {id: "4", title: "Book2", size: 299, metadata: {author: "Dr. Seuss"}}
    ];

    const combined = entries.concat(nextEntries);

    const spySearchCount = spyOn(component.api, "search_count").and.returnValue(Promise.resolve(new Success(combined.length)));
    const spySearch = spyOn(component.api, "search").and.returnValues(
      Promise.resolve(new Success(entries)),
      Promise.resolve(new Success(nextEntries))
    );

    component.ngOnInit();
    tick();
    fixture.detectChanges();
    tick();
    component.loadMore();
    tick();
    fixture.detectChanges();
    tick();

    expect(spySearchCount).toHaveBeenCalled();
    expect(spySearch).toHaveBeenCalled();
    expect(component.books).toEqual(combined);
  }));

  it('should display entries', fakeAsync(() => {
    const entries = [
      {id: "1", title: "Green Eggs and Ham", size: 99, metadata: {author: "Dr. Seuss"}},
      {id: "2", title: "Book", size: 199, metadata: {author: "Dr. Seuss"}}
    ];

    const nextEntries = [
      {id: "3", title: "Finding Religion with C++", size: 666, metadata: {author: "Dr. Seuss"}},
      {id: "4", title: "Book2", size: 299, metadata: {author: "Dr. Seuss"}}
    ];

    const combined = entries.concat(nextEntries);

    const spySearchCount = spyOn(component.api, "search_count").and.returnValue(Promise.resolve(new Success(combined.length)));
    const spySearch = spyOn(component.api, "search").and.returnValues(
      Promise.resolve(new Success(entries)),
      Promise.resolve(new Success(nextEntries))
    );

    component.ngOnInit();
    tick();
    fixture.detectChanges();
    tick();
    component.loadMore();
    tick();
    fixture.detectChanges();
    tick();

    expect(spySearchCount).toHaveBeenCalled();
    expect(spySearch).toHaveBeenCalled();

    const elements = queryElements<HTMLElement>(fixture, "app-book-listing");
    expect(elements.length).toEqual(combined.length);

    zip(elements, combined).forEach(([e, c]) => {
      expect(e.innerText).toContain(c.title);
    })
  }));
});
