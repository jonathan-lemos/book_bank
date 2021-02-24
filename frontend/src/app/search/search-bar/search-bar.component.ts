import {Component, EventEmitter, OnInit, Output} from '@angular/core';
import {ApiService} from "../../services/api/api.service";
import {AuthService} from "../../services/auth.service";
import {FaIconLibrary} from '@fortawesome/angular-fontawesome';
import {faSearch} from '@fortawesome/free-solid-svg-icons';
import Book from 'src/app/services/api/schemas/book';
import throttle from 'src/utils/throttle';

@Component({
  selector: 'app-search-bar',
  templateUrl: './search-bar.component.html',
  styleUrls: ['./search-bar.component.sass']
})
export class SearchBarComponent implements OnInit {
  searchText: string = "";
  suggestions: Book[] = [];

  @Output() search = new EventEmitter<string>()
  @Output() onClickSuggestion = new EventEmitter<Book>()
  throttledKeyUpHandler = throttle(async (query: string, auth: AuthService) => {
    const res = await this.api.suggestions(query, auth);
    res.match(
      success => {
        this.suggestions = success;
      },
      failure => console.log(failure)
    );
  }, 250);

  constructor(private api: ApiService, private auth: AuthService, library: FaIconLibrary) {
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

    this.throttledKeyUpHandler(this.searchText, this.auth);
  }
}
