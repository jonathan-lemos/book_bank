import {Component, EventEmitter, Input, OnInit, Output} from '@angular/core';
import Book from "../../services/api/schemas/book";
import {cover} from "../../../utils/routing";
import {sizeUnit} from "../../../utils/size";
import {round} from "../../../utils/format";
import {AuthService} from "../../services/auth.service";
import {mapToList} from 'src/utils/misc';
import {FaIconLibrary} from '@fortawesome/angular-fontawesome';
import {faDownload, faEdit} from '@fortawesome/free-solid-svg-icons';

@Component({
  selector: 'app-book-view',
  templateUrl: './book-view.component.html',
  styleUrls: ['./book-view.component.sass']
})
export class BookViewComponent implements OnInit {
  @Input() book: Book | null = null;
  @Output() edit = new EventEmitter<void>();

  constructor(public auth: AuthService, library: FaIconLibrary) {
    library.addIcons(faEdit, faDownload);
  }

  get metadataList() {
    return mapToList(this.book?.metadata ?? {});
  }

  get size_string(): string {
    let [num, unit] = sizeUnit(this.book?.size ?? 0);
    return [round(num, 2), unit].join(" ");
  }

  ngOnInit(): void {
  }

  cover_url(): string {
    return cover(this.book?.id ?? "");
  }

  title(): string {
    return this.book?.title ?? "";
  }
}
