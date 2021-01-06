import {Component, Input, OnInit} from '@angular/core';
import Book from "../services/api/schemas/book";
import {AuthService} from "../services/auth.service";
import {ApiService} from "../services/api/api.service";
import {Result} from "../../utils/functional/result";
import {Router} from "@angular/router";

@Component({
  selector: 'app-book',
  templateUrl: './book.component.html',
  styleUrls: ['./book.component.sass']
})
export class BookComponent implements OnInit {
  @Input() book: Book;
  editing = false;
  promise: Promise<Result<string, string>> | null = null;
  promiseSource: "submit" | "delete" | null = null;

  constructor(private auth: AuthService, private api: ApiService, private router: Router) { }

  ngOnInit(): void {
  }

  async submitChanges(req: {title: string, metadata: {key: string, value: string}[]}): Promise<void> {
    if (this.promiseSource !== null) {
      return;
    }

    this.promise = this.api.updateBookMetadata(this.book.id, req.title, req.metadata, this.auth)
      .then(x => x.map_val(() => "The book metadata was updated successfully."));
    this.promiseSource = "submit";
  }

  async deleteBook(): Promise<void> {
    if (this.promiseSource !== null) {
      return;
    }

    this.promise = this.api.deleteBook(this.book.id, this.auth)
      .then(r => r.map_val(() => "The book was deleted successfully"));
    this.promiseSource = "delete";
  }

  async onClose(): Promise<void> {
    await this.promise.then(async r => {
      if (r.isSuccess()) {
        if (this.promiseSource === "submit") {
          await this.router.navigate([`book/${this.book.id}`])
        }
        else {
          await this.router.navigate(["home"]);
        }
      }
      else {
        console.log(r.value);
      }
    })
  }

}
