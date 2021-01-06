import {Component, OnInit} from '@angular/core';

@Component({
  selector: 'app-upload',
  templateUrl: './upload.component.html',
  styleUrls: ['./upload.component.sass']
})
export class UploadComponent implements OnInit {
  title: string = "";

  constructor() { }

  ngOnInit(): void {
  }

  get url() {
    return `${window.location.origin}/api/books`;
  }
}
