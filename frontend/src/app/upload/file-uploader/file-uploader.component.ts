import {AfterViewInit, Component, ElementRef, EventEmitter, OnInit, Output, Renderer2, ViewChild} from '@angular/core';
import * as pdfjs from "pdfjs-dist";
import {round} from 'src/utils/format';
import {fileToBinaryString} from "../../../utils/file";
import {sizeUnit} from "../../../utils/size";
import {FaIconLibrary} from '@fortawesome/angular-fontawesome';
import {faUpload} from '@fortawesome/free-solid-svg-icons';

@Component({
  selector: 'app-file-uploader',
  templateUrl: './file-uploader.component.html',
  styleUrls: ['./file-uploader.component.sass']
})
export class FileUploaderComponent implements OnInit, AfterViewInit {
  @ViewChild("file_input") file: ElementRef | null = null;
  @ViewChild("pdf_preview") pdf: ElementRef | null = null;

  filename: string = "";
  size: number | null = null;
  @Output() newFilename = new EventEmitter<string>();
  @Output() upload = new EventEmitter<{ filename: string, size: number }>();

  constructor(private renderer: Renderer2, library: FaIconLibrary) {
    library.addIcons(faUpload);
  }

  get uploadText(): string {
    const [n, unit] = sizeUnit(this.size ?? 0);
    const nstr = round(n, 2);
    return this.size === null || this.filename === null ? "Upload" : `Upload ${this.filename} (${nstr} ${unit})`;
  }

  ngOnInit(): void {
  }

  ngAfterViewInit(): void {
    if (this.file === null) {
      return;
    }

    const fileRef: HTMLInputElement = this.renderer.selectRootElement(this.file.nativeElement);

    const displayPdf = async () => {
      if (fileRef.files === null || fileRef.files.length === 0 || this.pdf === null) {
        return;
      }

      const file = fileRef.files[0];
      const b64 = await fileToBinaryString(file);
      pdfjs.GlobalWorkerOptions.workerSrc = 'pdf.worker.js';
      const doc = await pdfjs.getDocument({data: b64}).promise;
      const cover = await doc.getPage(1);

      const viewportUnscaled = cover.getViewport({scale: 1});

      const canvas: HTMLCanvasElement = this.renderer.selectRootElement(this.pdf.nativeElement);
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;

      const scale = canvas.offsetWidth / viewportUnscaled.width;
      canvas.height = viewportUnscaled.height * scale;

      const viewport = cover.getViewport({scale: scale});
      const ctx = canvas.getContext("2d");
      if (ctx === null) {
        console.error("canvas.getContext('2d') returned null.")
        return;
      }

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
}
