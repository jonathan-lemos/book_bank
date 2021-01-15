import { Component, ElementRef, OnInit, Renderer2, ViewChild } from '@angular/core';
import { Router } from '@angular/router';
import fetchProgress from 'src/utils/ajax';
import { Result } from 'src/utils/functional/result';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-upload',
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.sass']
})
export class UploadComponent implements OnInit {
  title: string = "";
  @ViewChild("upload_form") element: ElementRef;
  promiseObj: { promise: Promise<Result<string, string>>, progressCallbackRegistrationFunction: (cb: (progress: number, total: number) => void) => void } | null = null;
  private cb: (progress: number, total: number) => void | null = null;

  constructor(private renderer: Renderer2, private router: Router) { }

  ngOnInit(): void {
  }

  get url() {
    return `${window.location.origin}/api/books`;
  }

  upload() {
    const formEl = this.renderer.selectRootElement(this.element.nativeElement);
    const fd = new FormData(formEl);

    const prom = fetchProgress(`${window.location.origin}/api/books`, { method: "POST", body: fd }, (progress, total) => this.cb && this.cb(progress, total));
    this.promiseObj = { promise: prom.then(x => x.map_val(y => y.text).map_err(y => y.reason ?? "")), progressCallbackRegistrationFunction: c => this.cb = c };
  }

  async onClose(): Promise<void> {
    await this.promiseObj.promise.then(async r => {
      if (r.isSuccess()) {
        try {
          const jsonObject = JSON.parse(r.value);
        }
        await this.router.navigate([`book/${this.book.id}`])
      }
      else {
        console.log(r.value);
      }
    })
  }
}
