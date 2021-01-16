import { Component, ElementRef, OnInit, Renderer2, ViewChild } from '@angular/core';
import { Router } from '@angular/router';
import fetchProgress from 'src/utils/ajax';
import { Result } from 'src/utils/functional/result';
import validate from 'src/utils/validator';
import { ApiService } from '../services/api/api.service';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-upload',
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.sass']
})
export class UploadComponent implements OnInit {
  title: string = "";
  @ViewChild("upload_form") element: ElementRef;
  promise: Promise<Result<string, string>> | null = null;
  progress: number | null = null;
  total: number | null = null;

  constructor(private renderer: Renderer2, private api: ApiService, private auth: AuthService, private router: Router) { }

  ngOnInit(): void {
  }

  get url() {
    return `${window.location.origin}/api/books`;
  }

  upload() {
    const formEl = this.renderer.selectRootElement(this.element.nativeElement);
    const fd = new FormData(formEl);

    this.promise = this.api.uploadBook(fd, this.auth, (progress, total) => {
      this.progress = progress;
      this.total = total;
    });
  }

  async onClose(): Promise<void> {
    await this.promise.then(async r => {
      if (r.isSuccess()) {
        await this.router.navigate([`book/${r.value}`])
      }
      else {
        console.log(r.value);
      }
    })
  }
}
