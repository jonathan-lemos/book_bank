import {BrowserModule} from '@angular/platform-browser';
import {NgModule} from '@angular/core';

import {AppRoutingModule} from './app-routing.module';
import {AppComponent} from './app.component';
import {LoginComponent} from './login/login.component';
import {SearchBarComponent} from './search/search-bar/search-bar.component';
import {FontAwesomeModule} from '@fortawesome/angular-fontawesome';
import {FormsModule} from "@angular/forms";
import {HomeComponent} from './home/home.component';
import {SearchComponent} from './search/search/search.component';
import {BookListingComponent} from './search/book-listing/book-listing.component';
import {NavbarComponent} from './navbar/navbar.component';
import {LinkComponent} from './navbar/link/link.component';
import {BookViewComponent} from './book/book-view/book-view.component';
import {BookEditComponent} from './book/book-edit/book-edit.component';
import {BookComponent} from './book/book.component';
import {LoadingComponent} from './loading/loading.component';
import {UploadComponent} from './upload/upload.component';
import {FileUploaderComponent} from './upload/file-uploader/file-uploader.component';
import {KeyValueEditorComponent} from './book/book-edit/key-value-editor/key-value-editor.component';
import {InfiniteScrollModule} from "ngx-infinite-scroll";
import { TextInputComponent } from './form/text-input/text-input.component';

@NgModule({
  declarations: [
    AppComponent,
    LoginComponent,
    SearchBarComponent,
    HomeComponent,
    SearchComponent,
    BookListingComponent,
    NavbarComponent,
    LinkComponent,
    BookViewComponent,
    BookEditComponent,
    BookComponent,
    LoadingComponent,
    UploadComponent,
    FileUploaderComponent,
    KeyValueEditorComponent,
    TextInputComponent,
  ],
    imports: [
        BrowserModule,
        AppRoutingModule,
        FontAwesomeModule,
        FormsModule,
        InfiniteScrollModule
    ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule {
}
