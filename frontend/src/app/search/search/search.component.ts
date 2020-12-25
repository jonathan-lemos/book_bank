import { Component, OnInit } from '@angular/core';
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
  books: Book[] | undefined;
  err: string | undefined;
  query: string = "";
  page: number = 0;
  count: number = 20;

  constructor(private auth: AuthService, private api: ApiService, private av: ActivatedRoute) { }

  async ngOnInit(): Promise<void> {
    const auth = this.auth.auth();
    if (auth === null) {
      return;
    }

    this.query = this.av.snapshot.paramMap.get("query") ?? "";

    const res = this.api.search(this.query, auth, this.count);
  }

}
