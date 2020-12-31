import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import Book from "../../services/api/schemas/book";
import {cover} from "../../../utils/routing";
import {size_unit} from "../../../utils/size";
import {round} from "../../../utils/format";
import {AuthService} from "../../services/auth.service";

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

  cover_url(): string {
    return cover(this.book.id);
  }

  get size_string(): string {
    let [num, unit] = size_unit(this.book.size);
    return [round(num, 2), unit].join(" ");
  }
}
