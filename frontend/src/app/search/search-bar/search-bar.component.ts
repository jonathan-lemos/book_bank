import { Component, EventEmitter, OnInit, Output } from '@angular/core';
import { ApiService } from "../../services/api/api.service";
import { AuthService } from "../../services/auth.service";
import { FontAwesomeModule, FaIconLibrary } from '@fortawesome/angular-fontawesome';
import { faSearch } from '@fortawesome/free-solid-svg-icons';
import Book from 'src/app/services/api/schemas/book';

@Component({
  selector: 'app-search-bar',
  templateUrl: './search-bar.component.html',
  styleUrls: ['./search-bar.component.sass']
})
export class SearchBarComponent implements OnInit {
  searchText: string = "";
  suggestions: Book[] = [];
  lastQuery: number = Date.now();

  @Output() search = new EventEmitter<string>()
  @Output() onClickSuggestion = new EventEmitter<Book>()

  constructor(private api: ApiService, private auth: AuthService, private library: FaIconLibrary) {
    library.addIcons(faSearch);
  }

  ngOnInit(): void {
  }

  async onKeyUp(e: KeyboardEvent): Promise<void> {
    if (e.key === "Enter") {
      this.search.emit(this.searchText);
      return;
    }

    if (!(e.target instanceof HTMLInputElement)) {
      return;
    }

    const now = Date.now();

    if (now - this.lastQuery < 500) {
      return;
    }

    this.lastQuery = now;

    const res = await this.api.suggestions(this.searchText, this.auth);
    res.match(
      success => {
        this.suggestions = success;
      },
      failure => console.log(failure)
    );
  }
}
