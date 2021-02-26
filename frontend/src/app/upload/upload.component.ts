import {Component, ElementRef, OnInit, ViewChild} from '@angular/core';
import {Router} from '@angular/router';
import {Result} from 'src/utils/functional/result';
import {ApiService} from '../services/api/api.service';
import {AuthService} from '../services/auth.service';

@Component({
  selector: 'app-upload',
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.sass']
})
export class UploadComponent implements OnInit {
  title: string = "";
  @ViewChild("upload_form") element: ElementRef | null = null;
  promise: Promise<Result<string, string>> | null = null;
  progress: number | null = null;
  total: number | null = null;

  constructor(private api: ApiService, private auth: AuthService, private router: Router) {
  }

  get url() {
    return `${window.location.origin}/api/books`;
  }

  get loadingPromise() {
    return this.promise?.then(id => id.map_val(val => `New book id: ${val}`)) ?? null;
  }

  ngOnInit(): void {
  }

  upload() {
    if (this.element === null) {
      return;
    }

    const formEl = this.element.nativeElement;
    const fd = new FormData(formEl);

    this.promise = this.api.uploadBook(fd, this.auth, (progress, total) => {
      this.progress = progress;
      this.total = total;
    }).then(id => id.map_val(val => `New book id: ${val}`));
  }

  async onClose(): Promise<void> {
    if (this.promise === null) {
      return;
    }

    await this.promise.then(async r => {
      if (r.isSuccess()) {
        await this.router.navigate([`/book/${r.value}`]).catch(console.error);
      } else {
        console.log(r.value);
      }
    })
  }
}
