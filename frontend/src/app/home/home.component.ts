import {Component, OnInit} from '@angular/core';
import {Router} from '@angular/router';
import Book from '../services/api/schemas/book';

@Component({
  selector: 'app-home',
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.sass']
})
export class HomeComponent implements OnInit {
  constructor(private router: Router) {
  }

  ngOnInit(): void {
  }

  search(query: string) {
    this.router.navigate([`/search/${query}`]).catch(console.error);
  }

  suggestion(book: Book) {
    this.router.navigate([`/book/${book.id}`]).catch(console.error);
  }
}
