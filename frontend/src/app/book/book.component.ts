import {Component, OnInit} from '@angular/core';
import Book from "../services/api/schemas/book";
import {AuthService} from "../services/auth.service";
import {ApiService} from "../services/api/api.service";
import {Failure, Result} from "../../utils/functional/result";
import {ActivatedRoute, Router} from "@angular/router";

@Component({
  selector: 'app-book',
  templateUrl: './book.component.html',
  styleUrls: ['./book.component.sass']
})
export class BookComponent implements OnInit {
  book: Result<Book, string> | null = null;
  editing = false;
  promise: Promise<Result<string, string>> | null = null;
  promiseSource: "submit" | "delete" | null = null;

  constructor(private auth: AuthService, private api: ApiService, private router: Router, private av: ActivatedRoute) {
  }

  async ngOnInit(): Promise<void> {
    const id = this.av.snapshot.paramMap.get("id");
    if (id == null) {
      this.book = new Failure("No book given.");
      return;
    }

    this.book = await this.api.book(id);
  }

  async submitChanges(req: { title: string, metadata: { [key: string]: string } }): Promise<void> {
    if (this.promiseSource !== null) {
      return;
    }

    if (!this.book?.isSuccess()) {
      return;
    }

    this.promise = this.api.updateBookMetadata(this.book.value.id, req.title, req.metadata, this.auth)
      .then(x => x.map_val(() => "The book metadata was updated successfully."));
    this.promiseSource = "submit";
  }

  async deleteBook(): Promise<void> {
    if (this.promiseSource !== null) {
      return;
    }

    if (!this.book?.isSuccess()) {
      return;
    }

    this.promise = this.api.deleteBook(this.book.value.id, this.auth)
      .then(r => r.map_val(() => "The book was deleted successfully"));
    this.promiseSource = "delete";
  }

  async onClose(): Promise<void> {
    if (!this.promise) {
      return;
    }

    await this.promise.then(async r => {
      if (r.isSuccess()) {
        if (this.promiseSource === "submit") {
          if (this.book?.isSuccess()) {
            await this.router.navigate([`/book/${this.book.value.id}`]).catch(console.error)
          }
        } else {
          await this.router.navigate(["/home"]).catch(console.error);
        }
      } else {
        console.log(r.value);
      }
    })
  }

  hasBook(): boolean {
    return this.book !== null && this.book.isSuccess();
  }

  getBook(): Book {
    return this.book?.value as Book;
  }

}
