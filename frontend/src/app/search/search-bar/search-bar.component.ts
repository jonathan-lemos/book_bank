import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import {ApiService} from "../../services/api/api.service";
import Suggestion from "../../services/api/schemas/suggestion";
import {AuthService} from "../../services/auth.service";

@Component({
  selector: 'app-search-bar',
  templateUrl: './search-bar.component.html',
  styleUrls: ['./search-bar.component.sass']
})
export class SearchBarComponent implements OnInit {
  searchText: string = "";
  suggestions: Suggestion[] = [];

  @Output() submit = new EventEmitter<string>()

  constructor(private api: ApiService, private auth: AuthService) { }

  ngOnInit(): void {
  }

  async onKeyUp(e: KeyboardEvent): Promise<void> {
    if (e.key === "Enter") {
      this.submit.emit(this.searchText);
      return;
    }

    if (!(e.target instanceof HTMLInputElement)) {
      return;
    }

    const auth = this.auth.auth();
    if (auth === null) {
      return;
    }
    const res = await this.api.suggestions(this.searchText, auth);
    res.match(
      success => {
        this.suggestions = success;
      },
      failure => console.log(failure)
    );
  }
}
