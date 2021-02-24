import {Component, OnInit} from '@angular/core';
import Book from "../../services/api/schemas/book";
import {ApiService} from "../../services/api/api.service";
import {AuthService} from "../../services/auth.service";
import {ActivatedRoute} from "@angular/router";

@Component({
  selector: 'app-search',
  templateUrl: './search.component.html',
  styleUrls: ['./search.component.sass']
})
export class SearchComponent implements OnInit {
  books: Book[] = [];
  err: string = "";
  query: string = "";
  page: number = 0;
  per_page_count: number = 20;
  max_count: number = 0;
  done: boolean = false;

  constructor(private auth: AuthService, private api: ApiService, private av: ActivatedRoute) {
  }

  async ngOnInit(): Promise<void> {
    this.query = this.av.snapshot.paramMap.get("query") ?? "";

    (await this.api.search_count(this.query, this.auth)).match(
      success => {
        this.max_count = success;
      },
      failure => {
        this.err = failure;
        this.done = true;
      }
    );
  }

  async onIntersectChange(b: boolean): Promise<void> {
    b && await this.loadMore();
  }

  async loadMore(): Promise<void> {
    if (this.done) {
      return;
    }

    const res = await this.api.search(this.query, this.auth, this.per_page_count, this.page);
    res.match(
      s => {
        this.books.push(...s);
        this.page++;
        if (s.length === 0) {
          this.done = true;
        }
      },
      f => {
        this.done = true;
        this.err = f;
      }
    );
  }
}
