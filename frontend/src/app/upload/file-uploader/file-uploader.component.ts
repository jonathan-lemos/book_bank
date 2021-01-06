import {AfterViewInit, Component, ElementRef, EventEmitter, OnInit, Output, Renderer2, ViewChild} from '@angular/core';
import * as pdfjs from "pdfjs-dist";
import {fileToBase64} from "../../../utils/file";
import {sizeUnit} from "../../../utils/size";

@Component({
  selector: 'app-file-uploader',
  templateUrl: './file-uploader.component.html',
  styleUrls: ['./file-uploader.component.sass']
})
export class FileUploaderComponent implements OnInit, AfterViewInit {
  @ViewChild("file_input") file: ElementRef;
  @ViewChild("pdf_preview") pdf: ElementRef;

  filename: string | null = null;
  size: number | null = null;
  @Output() newFilename = new EventEmitter<string>();
  @Output() upload = new EventEmitter<{filename: string, size: number}>();

  constructor(private renderer: Renderer2) { }

  ngOnInit(): void {
  }

  ngAfterViewInit(): void {
    const fileRef: HTMLInputElement = this.renderer.selectRootElement(this.file.nativeElement);

    const displayPdf = async () => {
      if (fileRef.files === null || fileRef.files.length === 0) {
        this.filename = null;
        this.size = null;
        return;
      }

      const file = fileRef.files[0];
      const b64 = await fileToBase64(file);
      const doc = await pdfjs.getDocument(b64).promise;
      const cover = await doc.getPage(1);

      const viewportUnscaled = cover.getViewport({scale: 1});

      const canvas: HTMLCanvasElement = this.renderer.selectRootElement(this.pdf.nativeElement);
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;

      const scale = canvas.offsetWidth / viewportUnscaled.width;

      const viewport = cover.getViewport({scale: scale});
      const ctx = canvas.getContext("2d");

      cover.render({canvasContext: ctx, viewport: viewport});

      this.newFilename.emit(file.name);
      this.filename = file.name;
      this.size = file.size;
    }

    fileRef.onchange = displayPdf;
    fileRef.onresize = displayPdf;
  }

  tryUpload() {
    if (this.filename !== null && this.size !== null) {
      this.upload.emit({filename: this.filename, size: this.size});
    }
  }

  get uploadText(): string {
    return this.size === null || this.filename === null ? "Upload" : `Upload ${this.filename} (${sizeUnit(this.size).join(" ")})`;
  }
}
