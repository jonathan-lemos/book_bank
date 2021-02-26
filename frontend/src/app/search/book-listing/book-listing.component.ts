import {Component, Input, OnInit} from '@angular/core';
import Book from "../../services/api/schemas/book";
import {thumbnail} from "../../../utils/routing";
import {mapToList} from 'src/utils/misc';

@Component({
  selector: 'app-book-listing',
  templateUrl: './book-listing.component.html',
  styleUrls: ['./book-listing.component.sass']
})
export class BookListingComponent implements OnInit {
  @Input() book: Book | null = null;

  constructor() {
  }

  get metadataList() {
    return mapToList(this.book?.metadata ?? {});
  }

  ngOnInit(): void {
  }

  thumbnail(): string {
    return thumbnail(this.book?.id ?? "");
  }

  title(): string {
    return this.book?.title ?? "";
  }

}
