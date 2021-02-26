import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import Book from "../../services/api/schemas/book";
import {cover} from "../../../utils/routing";
import {AuthService} from "../../services/auth.service";
import {FaIconLibrary} from '@fortawesome/angular-fontawesome';
import {faBan, faSave, faTrash} from '@fortawesome/free-solid-svg-icons';

@Component({
  selector: 'app-book-edit',
  templateUrl: './book-edit.component.html',
  styleUrls: ['./book-edit.component.sass']
})
export class BookEditComponent implements OnInit {
  @Input() book: Book | null = null;
  new_title: string = "";
  confirm_delete = false;

  @Output() submit = new EventEmitter<{ title: string, metadata: { [key: string]: string } }>();
  @Output() cancel = new EventEmitter<void>();
  @Output() del = new EventEmitter<void>();

  constructor(public auth: AuthService, library: FaIconLibrary) {
    library.addIcons(faBan, faSave, faTrash);
  }

  ngOnInit(): void {
    this.new_title = this.book?.title ?? "";
  }

  coverUrl(): string {
    return cover(this.book?.id ?? "[null]");
  }

  handleSubmit(): void {
    if (this.book == null) {
      return;
    }

    this.submit.emit({
      title: this.new_title,
      metadata: this.book.metadata
    });
  }
}
