import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import Book from "../../services/api/schemas/book";
import { cover } from "../../../utils/routing";
import { AuthService } from "../../services/auth.service";

@Component({
  selector: 'app-book-edit',
  templateUrl: './book-edit.component.html',
  styleUrls: ['./book-edit.component.sass']
})
export class BookEditComponent implements OnInit {
  @Input() book: Book;
  new_meta: { number: number | null, key: string, value: string }[] = [];
  new_title: string;
  confirm_delete = false;

  @Output() submit = new EventEmitter<{ title: string, metadata: { [key: string]: string } }>();
  @Output() cancel = new EventEmitter<void>();
  @Output() del = new EventEmitter<void>();

  constructor(public auth: AuthService) { }

  ngOnInit(): void {
    this.new_meta = [...Object.keys(this.book.metadata).map(key => ({ key: key, value: this.book.metadata[key] }))].map((x, i) => ({ number: i, ...x }));
    this.new_title = this.book.title;
  }

  coverUrl(): string {
    return cover(this.book.id);
  }

  addRow(): void {
    const t = this.new_meta[this.new_meta.length - 1];
    if (t.number === null && t.key === "" && t.value === "") {
      return;
    }
    this.new_meta.push({ number: null, key: "", value: "" });
  }

  deleteRow(row: number): void {
    this.new_meta.splice(row, 1);
  }

  handleSubmit(): void {
    this.submit.emit({ title: this.new_title, metadata: this.new_meta.reduce((a, c) => Object.assign(a, { [c.key]: c.value }), {}) });
  }
}
