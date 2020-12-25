import { BrowserModule } from '@angular/platform-browser';
import { NgModule } from '@angular/core';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { TitleBarComponent } from './title-bar/title-bar.component';
import { LoginComponent } from './login/login.component';
import { SearchBarComponent } from './search/search-bar/search-bar.component';
import { FontAwesomeModule } from '@fortawesome/angular-fontawesome';
import {FormsModule} from "@angular/forms";
import { HomeComponent } from './home/home.component';
import { SearchComponent } from './search/search/search.component';
import { BookListingComponent } from './search/book-listing/book-listing.component';
import { BookComponent } from './book/book.component';

@NgModule({
  declarations: [
    AppComponent,
    TitleBarComponent,
    LoginComponent,
    SearchBarComponent,
    HomeComponent,
    SearchComponent,
    BookListingComponent,
    BookComponent
  ],
    imports: [
        BrowserModule,
        AppRoutingModule,
        FontAwesomeModule,
        FormsModule
    ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
