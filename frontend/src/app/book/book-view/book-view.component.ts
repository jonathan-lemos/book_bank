import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import Book from "../../services/api/schemas/book";
import {cover} from "../../../utils/routing";
import {sizeUnit} from "../../../utils/size";
import {round} from "../../../utils/format";
import {AuthService} from "../../services/auth.service";
import { mapToList } from 'src/utils/misc';

@Component({
  selector: 'app-book-view',
  templateUrl: './book-view.component.html',
  styleUrls: ['./book-view.component.sass']
})
export class BookViewComponent implements OnInit {
  @Input() book: Book;
  @Output() edit = new EventEmitter<void>();

  constructor(public auth: AuthService) { }

  ngOnInit(): void {
  }

  get metadataList() {
    return mapToList(this.book.metadata);
  }

  cover_url(): string {
    return cover(this.book.id);
  }

  get size_string(): string {
    let [num, unit] = sizeUnit(this.book.size);
    return [round(num, 2), unit].join(" ");
  }
}
